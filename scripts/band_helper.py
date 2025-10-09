#!scripts/venv/bin/python3

import sys
import nrarfcn as nr


# This function is part of srsRAN (band_helper.cc).
def abs_freq_point_a_arfcn(arfcn):
  arfcn = int(arfcn)
  srsran_subcarrier_spacing_15kHz = 0
  SRSRAN_NRE = 12
  nof_prb = 106

  # Defines the symbol duration, including cyclic prefix
  def SRSRAN_SUBC_SPACING_NR(NUM): return 15000 << NUM

  def get_abs_freq_point_a_from_center_freq(nof_prb, center_freq):
    # for FR1 unit of resources blocks for freq calc is always 180kHz regardless for actual SCS of carrier
    # TODO: add offset_to_carrier
    return center_freq - (nof_prb / 2 * SRSRAN_SUBC_SPACING_NR(srsran_subcarrier_spacing_15kHz) * SRSRAN_NRE)

  return nr.get_nrarfcn(get_abs_freq_point_a_from_center_freq(
    nof_prb, nr.get_frequency(arfcn) * 1000000) / 1000000)

def arfcn_to_freq(arfcn):
  return int(nr.get_frequency(int(arfcn)) * 1000000)


# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <sebastien.dudek(<@T>)synacktiv.com> wrote (part of) this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return FlUxIuS ;)
# ----------------------------------------------------------------------------

table_earfcn = {
  1 :  { 'FDL_Low' : 2110,   'NDL_Offset' : 0,     'DL_range' : (0,599),       'FUL_Low' : 1920,   'NUL_Offset' : 18000,  'UP_range' : (1800,18599),    },
  2 :  { 'FDL_Low' : 1930,   'NDL_Offset' : 600,   'DL_range' : (600,1199),    'FUL_Low' : 1850,   'NUL_Offset' : 18600,  'UP_range' : (18600,19199),   },
  3 :  { 'FDL_Low' : 1805,   'NDL_Offset' : 1200,  'DL_range' : (1200,1949),   'FUL_Low' : 1710,   'NUL_Offset' : 19200,  'UP_range' : (19200,19949),   },
  4 :  { 'FDL_Low' : 2110,   'NDL_Offset' : 1950,  'DL_range' : (1950,2399),   'FUL_Low' : 1710,   'NUL_Offset' : 19950,  'UP_range' : (19950,20399),   },
  5 :  { 'FDL_Low' : 869,    'NDL_Offset' : 2400,  'DL_range' : (2400,2649),   'FUL_Low' : 824,    'NUL_Offset' : 20400,  'UP_range' : (20400,20649),   },
  6 :  { 'FDL_Low' : 875,    'NDL_Offset' : 2650,  'DL_range' : (2650,2749),   'FUL_Low' : 830,    'NUL_Offset' : 20650,  'UP_range' : (20650,20749),   },
  7 :  { 'FDL_Low' : 2620,   'NDL_Offset' : 2750,  'DL_range' : (2750,3449),   'FUL_Low' : 2500,   'NUL_Offset' : 20750,  'UP_range' : (20750,21449),   },
  8 :  { 'FDL_Low' : 925,    'NDL_Offset' : 3450,  'DL_range' : (3450,3799),   'FUL_Low' : 880,    'NUL_Offset' : 21450,  'UP_range' : (21450,21799),   },
  9 :  { 'FDL_Low' : 1844.9, 'NDL_Offset' : 3800,  'DL_range' : (3800,4149),   'FUL_Low' : 1749.9, 'NUL_Offset' : 21800,  'UP_range' : (21800,22149),   },
  10 : { 'FDL_Low' : 2110,   'NDL_Offset' : 4150,  'DL_range' : (4150,4749),   'FUL_Low' : 1710,   'NUL_Offset' : 22150,  'UP_range' : (22150,22749),   },
  11 : { 'FDL_Low' : 1475.9, 'NDL_Offset' : 4750,  'DL_range' : (4750,4949),   'FUL_Low' : 1427.9, 'NUL_Offset' : 22750,  'UP_range' : (22750,22949),   },
  12 : { 'FDL_Low' : 729,    'NDL_Offset' : 5010,  'DL_range' : (5010,5179),   'FUL_Low' : 699,    'NUL_Offset' : 23010,  'UP_range' : (23010,23179),   },
  13 : { 'FDL_Low' : 746,    'NDL_Offset' : 5180,  'DL_range' : (5180,5279),   'FUL_Low' : 777,    'NUL_Offset' : 23180,  'UP_range' : (23180,23279),   },
  14 : { 'FDL_Low' : 758,    'NDL_Offset' : 5280,  'DL_range' : (5280,5379),   'FUL_Low' : 788,    'NUL_Offset' : 23280,  'UP_range' : (23280,23379),   },
  17 : { 'FDL_Low' : 734,    'NDL_Offset' : 5730,  'DL_range' : (5730,5849),   'FUL_Low' : 704,    'NUL_Offset' : 23730,  'UP_range' : (23730,23849),   },
  18 : { 'FDL_Low' : 860,    'NDL_Offset' : 5850,  'DL_range' : (5850,5999),   'FUL_Low' : 815,    'NUL_Offset' : 23850,  'UP_range' : (23850,23999),   },
  19 : { 'FDL_Low' : 875,    'NDL_Offset' : 6000,  'DL_range' : (6000,6149),   'FUL_Low' : 830,    'NUL_Offset' : 24000,  'UP_range' : (24000,24149),   },
  20 : { 'FDL_Low' : 791,    'NDL_Offset' : 6150,  'DL_range' : (6150,6449),   'FUL_Low' : 832,    'NUL_Offset' : 24150,  'UP_range' : (24150,24449),   },
  21 : { 'FDL_Low' : 1495.9, 'NDL_Offset' : 6450,  'DL_range' : (6450,6599),   'FUL_Low' : 1447.9, 'NUL_Offset' : 24450,  'UP_range' : (24450,24599),   },
  22 : { 'FDL_Low' : 3510,   'NDL_Offset' : 6600,  'DL_range' : (6600,7399),   'FUL_Low' : 3410,   'NUL_Offset' : 24600,  'UP_range' : (24600,25399),   },
  23 : { 'FDL_Low' : 2180,   'NDL_Offset' : 7500,  'DL_range' : (7500,7699),   'FUL_Low' : 2000,   'NUL_Offset' : 25500,  'UP_range' : (25500,25699),   },
  24 : { 'FDL_Low' : 1525,   'NDL_Offset' : 7700,  'DL_range' : (7700,8039),   'FUL_Low' : 1626.5, 'NUL_Offset' : 25700,  'UP_range' : (25700,26039),   },
  25 : { 'FDL_Low' : 1930,   'NDL_Offset' : 8040,  'DL_range' : (8040,8689),   'FUL_Low' : 1850,   'NUL_Offset' : 26040,  'UP_range' : (26040,26689),   },
  26 : { 'FDL_Low' : 859,    'NDL_Offset' : 8690,  'DL_range' : (8690,9039),   'FUL_Low' : 814,    'NUL_Offset' : 26690,  'UP_range' : (26690,27039),   },
  27 : { 'FDL_Low' : 852,    'NDL_Offset' : 9040,  'DL_range' : (9040,9209),   'FUL_Low' : 807,    'NUL_Offset' : 27040,  'UP_range' : (27040,27209),   },
  28 : { 'FDL_Low' : 758,    'NDL_Offset' : 9210,  'DL_range' : (9210,9659),   'FUL_Low' : 703,    'NUL_Offset' : 27210,  'UP_range' : (27210,27659),   },
  30 : { 'FDL_Low' : 2350,   'NDL_Offset' : 9770,  'DL_range' : (9770,9869),   'FUL_Low' : 2305,   'NUL_Offset' : 27660,  'UP_range' : (27660,27759),   },
  31 : { 'FDL_Low' : 462.5,  'NDL_Offset' : 9870,  'DL_range' : (9870,9919),   'FUL_Low' : 452.5,  'NUL_Offset' : 27760,  'UP_range' : (27760,27809),   },
  65 : { 'FDL_Low' : 2110,   'NDL_Offset' : 65536, 'DL_range' : (65536,66435), 'FUL_Low' : 1920,   'NUL_Offset' : 131072, 'UP_range' : (131072,131971), },
  66 : { 'FDL_Low' : 2110,   'NDL_Offset' : 66436, 'DL_range' : (66436,67335), 'FUL_Low' : 1710,   'NUL_Offset' : 131972, 'UP_range' : (131972,132671), },
  68 : { 'FDL_Low' : 753,    'NDL_Offset' : 67536, 'DL_range' : (67536,67835), 'FUL_Low' : 698,    'NUL_Offset' : 132672, 'UP_range' : (132672,132971), },
  70 : { 'FDL_Low' : 1995,   'NDL_Offset' : 68336, 'DL_range' : (68336,68585), 'FUL_Low' : 1695,   'NUL_Offset' : 132972, 'UP_range' : (132972,133121), },
  71 : { 'FDL_Low' : 617,    'NDL_Offset' : 68586, 'DL_range' : (68586,68935), 'FUL_Low' : 663,    'NUL_Offset' : 133122, 'UP_range' : (133122,133471), },
  72 : { 'FDL_Low' : 461,    'NDL_Offset' : 68936, 'DL_range' : (68936,68985), 'FUL_Low' : 451,    'NUL_Offset' : 133472, 'UP_range' : (133472,133521), },
  73 : { 'FDL_Low' : 460,    'NDL_Offset' : 68986, 'DL_range' : (68986,69465), 'FUL_Low' : 450,    'NUL_Offset' : 133522, 'UP_range' : (133522,133571), },
  74 : { 'FDL_Low' : 1475,   'NDL_Offset' : 69036, 'DL_range' : (69036,69035), 'FUL_Low' : 1427,   'NUL_Offset' : 133572, 'UP_range' : (133572,134001), },
  85 : { 'FDL_Low' : 728,    'NDL_Offset' : 70366, 'DL_range' : (70366,70545), 'FUL_Low' : 698,    'NUL_Offset' : 134002, 'UP_range' : (134002,134181), },
}

def earfcn2freq(band, dl_earfcn=None, ul_earfcn=None):
  NDL_Offset = table_earfcn[band]['NDL_Offset']
  NUL_Offset = table_earfcn[band]['NUL_Offset']
  duplex_spacing = abs(table_earfcn[band]['FDL_Low']-table_earfcn[band]['FUL_Low'])
  FDL_Low = table_earfcn[band]['FDL_Low']
  FUL_Low = table_earfcn[band]['FUL_Low']
  downlink_freq = uplink_freq = None
  if dl_earfcn is not None:
    downlink_freq = FDL_Low + 0.1 * (dl_earfcn-NDL_Offset)
  if ul_earfcn is not None:
    uplink_freq = FUL_Low + 0.1 * (ul_earfcn-NUL_Offset)
  if downlink_freq is not None and uplink_freq is None:
    uplink_freq = downlink_freq - duplex_spacing
  elif downlink_freq is None and uplink_freq is not None:
    downlink_freq = downlink_freq + duplex_spacing
  return (int(downlink_freq * 1000000), int(uplink_freq * 1000000))

def earfcn_to_freq_dl(band, dl_earfcn):
  return earfcn2freq(int(band), int(dl_earfcn))[0]

def earfcn_to_freq_offset_ul(band, dl_earfcn):
  f = earfcn2freq(int(band), int(dl_earfcn))
  return f[1] - f[0]


if __name__ == "__main__":
  print(globals()[sys.argv[1]](*sys.argv[2:]))
