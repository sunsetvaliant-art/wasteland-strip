"""Latitude/longitude to game metres (0.2.50). Use ll() for anything new; fix() turns a position made with the old
short conversion (x = dlon * 111320 * cos(lat0), z = -dlat * 110574) into the game's frame. See tools/realign.py."""
import math
LAT0 = -28.3285718; LON0 = 153.4035024
KX0 = 111320 * math.cos(math.radians(LAT0)); KZ0 = 110574.0
SX, SZ = 1.00075033, 1.00226813          # assets/world/geo_fit.json
NORTH_Z = -16960.0                       # the north strip (tools/bake_north.py) was baked with the short conversion

def fix(x, z):
    if z < NORTH_Z: return round(x, 2), round(z, 2)
    return round(x * SX, 2), round(z * SZ, 2)

def ll(lon, lat):
    return fix((lon - LON0) * KX0, (LAT0 - lat) * KZ0)
