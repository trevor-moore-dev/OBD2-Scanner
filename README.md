# OBD-II Scanner Swift iOS Application

OBD2 Scanner iOS Application built in Swift. Can be used alongside any OBD2 Bluetooth adapter plugged into your vehicle's diagnostics port (currently configured for Veepeak OBDCheck BLE+).

## Resources
- [ELM327 Spec](https://www.elmelectronics.com/wp-content/uploads/2017/01/ELM327DS.pdf)
- [OBD-II PIDs](https://en.wikipedia.org/wiki/OBD-II_PIDs#Service_03_(no_PID_required))
- [DTC Descriptions](https://gist.github.com/wzr1337/8af2731a5ffa98f9d506537279da7a0e)
- [VIN Decoding](https://vpic.nhtsa.dot.gov/api//vehicles/DecodeVin/5Y2SL65876Z438228?format=json)

## TODO
1. ~~Bluetooth transport~~
2. ~~Setup PID data stream~~
3. ~~Terminal view~~
4. ~~Persist DTC descriptions~~
5. ~~Render DTCs~~
6. ~~Unify response parsing~~
7. ~~Render vehicle information~~
8. ~~Support standard PIDs~~
9. Clear DTCs
10. Multi-line VIN parsing
11. Multi-line PID requests

## Notes

#### PID Prefixes
- `01` - show current data
- `02` - show freeze frame data
- `03` - show diagnostic trouble codes
- `04` - clear trouble codes
- `07` - show pending trouble codes
- `09` - request vehicle info
- `0A` - request permanent trouble codes

#### Multi-line PID Requests
- Example: `01 11 05 0D 0C`
- Up to 6 parameters can be requested, in this example it's 4 (`11 05 0D 0C`).
- Response:
```
00A
0: 41 11 3F 05 44 0D
1: 21 0C 17 B8 00 00 00
```
- The first line tells us that the response is `00A` (decimal 10) bytes long. The first byte (`41`) can be ignored. Then what follows is the PID numbers followed by their data bytes. The trailing `00` bytes can be ignored.

#### Standard PIDs
- `01 06` - Short term fuel trim (bank 1)
- `01 07` - Long term fuel trim (bank 1)
- `01 08` - Short term fuel trim (bank 2)
- `01 09` - Long term fuel trim (bank 2)
- `01 0A` - Fuel pressure
- `01 0B` - Intake manifold absolute pressure
- `01 0F` - Intake air pressure
- `01 0E` - Timing advance

#### Read Number of DTCs
- Example: `01 01`
- Response: `41 01 81`
- Subtract `80` from the 3rd byte to get the count, i.e. `81` - `80` = `1`.

#### Read DTCs
- Example: `03`
- Response: `43 01 33 00 00 00 00`
- `01 33` is the DTC, but replace `0` with `P0` (see [ELM327 Spec](https://www.elmelectronics.com/wp-content/uploads/2017/01/ELM327DS.pdf) for further info), for a result of `P0133`, which maps to a DTC description.

#### VIN
- Example: `09 02`
- Response:
```
49 02 01 00 00 00 31
49 02 02 44 34 47 50
49 02 03 30 30 52 35
49 02 04 35 42 31 32
49 02 05 33 34 35 36
```
- The first 3 bytes on each row can be ignored, the last 4 bytes on each row are the in order response for the VIN. The VIN will be used to (obviously) ID and persist vehicles that the adapter has been connected to and scanned, as well as decoding make/model. See [here](https://vpic.nhtsa.dot.gov/api//vehicles/DecodeVin/5Y2SL65876Z438228?format=json) for further details.

#### Battery Voltage
- Example: `AT RV`
- Response: `12.5V`
