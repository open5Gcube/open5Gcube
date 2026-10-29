// Open external links in a new tab
document$.subscribe(() => {
    for (const link of document.querySelectorAll("a[href]")) {
        if (link.host !== location.host) {
            link.target = "_blank";
            link.rel = "noopener";
        }
    }
});
