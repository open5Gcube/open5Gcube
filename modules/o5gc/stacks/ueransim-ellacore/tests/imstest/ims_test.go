//go:build o5gc && linux

// Package imstest has the IMS tests of the ueransim-ellacore stack: two
// UERANSIM UEs register with Ella IMS over their ims PDU session and call each
// other. The UEs are test UEs of Ella IMS (testue), each run in the network
// namespace of its UERANSIM container. The tests use internal packages of Ella
// IMS, so ims.robot builds them inside its source tree, in the ellacore-ims
// image. Adapted from e2e/e2e_test.go of Ella IMS.
package imstest

import (
	"context"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/netip"
	"os"
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/ellanetworks/ims/internal/ipsec"
	"github.com/ellanetworks/ims/sip"
	"github.com/ellanetworks/ims/testue"
	"golang.org/x/sys/unix"
)

// subscriber is a UE of the stack, given by the O5GC_UE<n>_* environment
type subscriber struct {
	imsi, imei string
	k, opc     []byte
	pid        int
}

var imeis = []string{"353490069873319", "353490069873327"}

func env(t *testing.T, name string) string {
	t.Helper()

	v := os.Getenv(name)
	if v == "" {
		t.Skipf("%s not set: run through ims.robot", name)
	}

	return v
}

func hexEnv(t *testing.T, name string) []byte {
	t.Helper()

	b, err := hex.DecodeString(env(t, name))
	if err != nil {
		t.Fatalf("%s: %v", name, err)
	}

	return b
}

func subscriberOf(t *testing.T, i int) subscriber {
	t.Helper()

	prefix := fmt.Sprintf("O5GC_UE%d_", i+1)

	pid, err := strconv.Atoi(env(t, prefix+"PID"))
	if err != nil {
		t.Fatalf("%sPID: %v", prefix, err)
	}

	return subscriber{
		imsi: env(t, prefix+"IMSI"),
		imei: imeis[i],
		k:    hexEnv(t, prefix+"K"),
		opc:  hexEnv(t, prefix+"OPC"),
		pid:  pid,
	}
}

type netns struct {
	work chan func()
}

// enter runs a goroutine, locked to its thread, in the network namespace of
// pid: Do runs functions on it.
func enter(t *testing.T, pid int) *netns {
	t.Helper()

	fd, err := unix.Open(fmt.Sprintf("/proc/%d/ns/net", pid), unix.O_RDONLY|unix.O_CLOEXEC, 0)
	if err != nil {
		t.Fatalf("open netns of pid %d: %v", pid, err)
	}

	n := &netns{work: make(chan func())}
	errc := make(chan error, 1)

	go func() {
		runtime.LockOSThread()

		err := unix.Setns(fd, unix.CLONE_NEWNET)
		_ = unix.Close(fd)

		errc <- err

		if err != nil {
			return
		}

		for f := range n.work {
			f()
		}
	}()

	if err := <-errc; err != nil {
		t.Fatalf("setns to pid %d: %v", pid, err)
	}

	t.Cleanup(func() { close(n.work) })

	return n
}

func (n *netns) Do(f func()) {
	done := make(chan struct{})

	n.work <- func() {
		defer close(done)

		f()
	}

	<-done
}

// tunAddr is the IPv4 address of the UE's ims PDU session.
func tunAddr(tun string) (netip.Addr, error) {
	ifc, err := net.InterfaceByName(tun)
	if err != nil {
		return netip.Addr{}, err
	}

	addrs, err := ifc.Addrs()
	if err != nil {
		return netip.Addr{}, err
	}

	for _, a := range addrs {
		if p, err := netip.ParsePrefix(a.String()); err == nil && p.Addr().Is4() {
			return p.Addr(), nil
		}
	}

	return netip.Addr{}, errors.New("no IPv4 address on " + tun)
}

// newUE makes the test UE of subscriber i in its UE container.
func newUE(t *testing.T, i int) *testue.UE {
	t.Helper()

	sub := subscriberOf(t, i)

	pcscf, err := netip.ParseAddrPort(env(t, "O5GC_PCSCF"))
	if err != nil {
		t.Fatalf("O5GC_PCSCF: %v", err)
	}

	mncLength, err := strconv.Atoi(env(t, "O5GC_MNC_LENGTH"))
	if err != nil {
		t.Fatalf("O5GC_MNC_LENGTH: %v", err)
	}

	tun := env(t, "O5GC_TUN")
	ns := enter(t, sub.pid)

	var (
		local netip.Addr
		xfrm  *ipsec.XFRM
	)

	ns.Do(func() {
		if local, err = tunAddr(tun); err == nil {
			xfrm, err = ipsec.Open()
		}
	})

	if err != nil {
		t.Fatalf("UE %d: %v", i+1, err)
	}

	t.Cleanup(func() { _ = xfrm.Close() })

	u, err := testue.New(testue.Config{
		IMSI:      sub.imsi,
		MNCLength: mncLength,
		IMEI:      sub.imei,
		K:         sub.k,
		OPc:       sub.opc,
		PCSCF:     pcscf,
		Local:     local,
		Transport: sip.UDP,
		MMTel:     testue.MMTelConfig{AcceptCalls: true},
		Kernel:    testue.XFRMOf(xfrm),
		Do:        ns.Do,
		Logger: slog.New(slog.NewTextHandler(t.Output(),
			&slog.HandlerOptions{Level: slog.LevelDebug})).With("ue", i+1),
	})
	if err != nil {
		t.Fatal(err)
	}

	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		_ = u.Deregister(ctx)
		_ = u.Close()
	})

	return u
}

func ctx(t *testing.T) context.Context {
	c, cancel := context.WithTimeout(t.Context(), 30*time.Second)
	t.Cleanup(cancel)

	return c
}

func register(t *testing.T, u *testue.UE) {
	t.Helper()

	if err := u.Register(ctx(t)); err != nil {
		t.Fatalf("Register: %v", err)
	}

	s := u.State()
	t.Logf("registered %s: default IMPU %s, associated %v", u.IMPI(), s.DefaultIMPU, s.AssociatedURIs)
}

func incoming(t *testing.T, u *testue.UE) *testue.Call {
	t.Helper()

	select {
	case c := <-u.MMTel().Calls():
		return c
	case <-time.After(15 * time.Second):
		t.Fatal("no incoming call")
	}

	return nil
}

func ended(t *testing.T, c *testue.Call, want testue.EndReason) {
	t.Helper()

	select {
	case <-c.Done():
	case <-time.After(15 * time.Second):
		t.Fatalf("call still %s, want it ended by %s", c.State(), want)
	}

	if got := c.End(); got != want {
		t.Fatalf("call ended by %s, want %s", got, want)
	}
}

// pair registers both UEs.
func pair(t *testing.T) (*testue.UE, *testue.UE) {
	t.Helper()

	a, b := newUE(t, 0), newUE(t, 1)
	register(t, a)
	register(t, b)

	return a, b
}

func TestRegister(t *testing.T) {
	pair(t)
}

// TestCall has UE 1 call UE 2 by its number, the tel URI of its MSISDN that UE 2
// registered as default IMPU, UE 2 answer, and UE 1 hang up.
func TestCall(t *testing.T) {
	a, b := pair(t)
	c := ctx(t)

	target := b.State().DefaultIMPU
	if !strings.HasPrefix(target, "tel:+") {
		t.Fatalf("default IMPU %q of UE 2 is not a tel URI", target)
	}

	ac, err := a.MMTel().Invite(target, testue.CallOptions{})
	if err != nil {
		t.Fatalf("Invite %s: %v", target, err)
	}

	bc := incoming(t, b)

	if err := bc.Ring(c); err != nil {
		t.Fatalf("Ring: %v", err)
	}

	done := make(chan error, 1)

	go func() { done <- bc.Answer(c) }()

	if res, err := ac.Wait(c); err != nil || res.StatusCode != 200 {
		t.Fatalf("Wait = %v, %v, want 200", res, err)
	}

	if err := <-done; err != nil {
		t.Fatalf("Answer: %v", err)
	}

	if err := ac.Bye(ctx(t)); err != nil {
		t.Fatalf("Bye: %v", err)
	}

	ended(t, ac, testue.LocalBye)
	ended(t, bc, testue.RemoteBye)
}
