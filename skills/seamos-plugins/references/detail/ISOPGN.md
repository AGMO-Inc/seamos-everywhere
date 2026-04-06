# ISOPGN

- **Machine ID**: 547
- **Provider Class**: com.bosch.nevonex.isopgn.impl.ISOPGNProvider
- **Category**: ISO Standard

## Interfaces

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | AccPed1LowIdleSwitch | PGN | 0xF003 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Accelerator Pedal 1 Low Idle Switch |
| In | AccPed2LowIdleSwitch | PGN | 0xF003 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Accelerator Pedal 2 Low Idle Switch |
| In | AccPedKickdownSwitch | PGN | 0xF003 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Accelerator Pedal Kickdown Switch |
| In | AccpedPos1 | PGN | 0xF003 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Accelerator Pedal Position 1 in Percent Resolution: 0.4%/bit, 0 offset. |
| In | AccpedPos2 | PGN | 0xF003 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Accelerator Pedal Position 2 in Percent (SPN 29). Resolution: 0.4%/bit, 0 offset |
| In | ActEngPerTrq | PGN | 0xF004 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Actual Engine Torque in Percent (SPN 513). Resolution: 1%/bit, -125% offset |
| In | ActEngPerTrqFract | PGN | 0xF004 | Cyclic | 50ms | FLOAT | IMPLEMENTED | 0.0.1 | SPN - 4154, Actual Engine - Percent Torque (Fractional), This parameter displays an additional torque in percent of the … |
| In | Alti | PGN | 0xFEE8 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Altitude in meter (SPN 580). Resolution: 0.125 m/bit, -2500m offset |
| In | AmbAirt | PGN | 0xFEF5 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Ambient Air Temperature in °C (SPN 171). Resolution: 0.03125 °C/bit, -273°C offset |
| In | AT1DefTnkLvl | PGN | 0xFE56 | Cyclic | 1000ms | FLOAT | IMPLEMENTED | 0.0.1 | Aftertreatment 1 Diesel Exhaust Fluid Tank Level SPN: 3517 - The diesel exhaust fluid level height in mm in the diesel e … |
| In | AtLeastOnePTOEngd | PGN | 0xFDA4 | Cyclic | 100ms | INT | IMPLEMENTED | 0.0.1 | SPN : 3948, At least one PTO engaged, Indicates that at least one PTO is engaged |
| In | Barop | PGN | 0xFEF5 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Barometric Pressure in kPa (SPN 108). Resolution: 0.5 kPa/bit, 0 offset |
| In | BrkPedPos | PGN | 0xF001 | Cyclic | 100ms | FLOAT | IMPLEMENTED | 0.0.1 | Brake Pedal Position. SPN : 521 |
| In | CanIntrt | PGN | 0xFEF5 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Cab Interior Temperature in °C (SPN 170). Resolution: 0.03125 °C/bit, -273°C offset |
| In | CargoAmbt | PGN | 0xFEFC | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Cargo Ambient Temperature in °C (SPN 169). Resolution: 0.03125 °C/bit, -273°C offset |
| In | Combination_Vehicle_Weight | PGN | 0xFE70 | Cyclic | 10ms | DOUBLE | IMPLEMENTED | 0.0.1 | Combination Vehicle Weight SPN: 1760 - Gross Combination Vehicle Weight |
| In | CompassBearling | PGN | 0xFEE8 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Compass Bearing in degree (SPN 165). Resolution: 1/128 deg/bit, 0 offset |
| In | CrCtlCCVS | PGN | 0xFEF1 | Cyclic | 100ms | array | IMPLEMENTED | 0.0.1 | PGN 65265, CCVS1 1. Cruise Control Set Speed (CCVS1, PGN 65265, SPN 86) Rx 2. Cruise Control Active (CCVS1, PGN 65265, S … |
| In | CrlDevEngCtlSrcAdr | PGN | 0xF004 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Source Address of Controlling Device for Engine Control (SPN 1483). Resolution: 1 source address/bit, 0 offset |
| In | CTITireSt | PGN | 0xFEF4 | Cyclic | 10000ms | FLOAT | RELEASED | 0.0.1 | CTI Tire Status (SPN 1698). |
| In | CTIWhlEndElecFlt | PGN | 0xFEF4 | Cyclic | 10000ms | FLOAT | RELEASED | 0.0.1 | CTI Wheel End Electrical Fault (SPN 1697). |
| In | CTIWhlSnsrSt | PGN | 0xFEF4 | Cyclic | 10000ms | FLOAT | RELEASED | 0.0.1 | CTI Wheel Sensor Status (SPN 1699). |
| In | DraftNFrnt | PGN | 0xFE46 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Draft in N (SPN 1878, cp.A.19.7). Resolution: 10N/bit, -320000N offset |
| In | DraftNRe | PGN | 0xFE45 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Draft in N (SPN 1879 cp. A.19.8). Resolution: 10N/bit, -320000N offset |
| In | Drivers_Identification_Number | PGN | 0x00FE6B | Adhoc | - | array | IMPLEMENTED | 0.0.1 | Driver identification(0xFE6B) - Used to obtain the driver identity. |
| In | DrvDemEngPerTrq | PGN | 0xF004 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Driver's Demand Engine Torque in Percent (SPN 512). Resolution: 1%/bit, -125% offset |
| In | EEC3 | PGN | 0xFEDF | Cyclic | 10ms | array | IMPLEMENTED | 0.0.1 | Electronic Engine Controller 3 SPN: 514 - Nominal Friction - Percent Torque SPN: 515 - Engine's Desired Operating Speed … |
| In | EngAirIntkt | PGN | 0xFEF5 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Engine Air Inlet Temperature in °C (SPN 172). Resolution: 1°C/bit, -40°C offset |
| In | EngAvgFuEco | PGN | 0xFEF2 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Engine Average Fuel Economy in km/L (SPN 185). Resolution: 1/512km/L per bit, 0 offset |
| In | EngCltTemp | PGN | 0xFE69 | Cyclic | 1000ms | FLOAT | IMPLEMENTED | 0.0.1 | SPN : 1637, Engine Coolant Temperature (High Resolution), Temperature of liquid found in engine cooling system. The high … |
| In | EngCooltLvlPer | PGN | 0xFEEF | Cyclic | 500ms | FLOAT | RELEASED | 0.0.1 | Engine Coolant Level in Percent (SPN 111). Resolution: 0.4%/bit, 0 offset |
| In | EngCooltp | PGN | 0xFEEF | Cyclic | 500ms | FLOAT | RELEASED | 0.0.1 | Engine Coolant Pressure in kPa (SPN 109). Resolution: 2 kPa/bit, 0 offset |
| In | EngCooltt | PGN | 0xFEEE | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Engine Coolant Temperature in °C (SPN 110). Resolution: 1°C/bit, -40°C offset |
| In | EngCrkcsp | PGN | 0xFEEF | Cyclic | 500ms | FLOAT | RELEASED | 0.0.1 | Engine Crankcase Pressure in kPa (SPN 101). Resolution: 1/128 kPa/bit, -250kPa offset |
| In | EngDmdPerTrq | PGN | 0xF004 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Engine Demand Torque in Percent (SPN 2432). Resolution: 1%/bit, -125% offset |
| In | EngExtdCrkcsBlwByp | PGN | 0xFEEF | Cyclic | 500ms | FLOAT | RELEASED | 0.0.1 | Engine Extended Crankcase Blow-by Pressure in kPa (SPN 22). Resolution: 0.05kPa/bit, 0 offset |
| In | EngFuDlvp | PGN | 0xFEEF | Cyclic | 500ms | FLOAT | RELEASED | 0.0.1 | Engine Fuel Delivery Pressure in kPa (SPN 94). Resolution: 4kPa/bit, 0 offset |
| In | EngFuFltDftlp | PGN | 0xFEFC | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Engine Fuel Filter Differential Pressure in kPa (SPN 95). Resolution: 2kPa/bit, 0 offset |
| In | EngFuRatePerTime | PGN | 0xFEF2 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Amount of fuel consumed by engine per unit of time(SPN 183). Resolution: 0.05L/h per bit, 0 offset |
| In | EngFut1 | PGN | 0xFEEE | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Engine Fuel Temperature 1 in °C (SPN 174). Resolution: 1°C/bit, -40°C offset |
| In | EngIcot | PGN | 0xFEEE | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Engine Intercooler Temperature in °C (SPN 52). Resolution: 1°C/bit, -40°C offset |
| In | EngIcoThOpngPer | PGN | 0xFEEE | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Engine Intercooler Thermostat Opening in Percent (SPN 1134). Resolution: 0.4%/bit, 0 offset |
| In | EngOilFltDftlp | PGN | 0xFEFC | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Engine Oil Filter Differential Pressure in kPa (SPN 99). Resolution: 0.5 kPa/bit, 0 offset |
| In | EngOilLvlPer | PGN | 0xFEEF | Cyclic | 500ms | FLOAT | RELEASED | 0.0.1 | Engine Oil Level in Percent (SPN 98). Resolution: 0.4%/bit, 0 offset |
| In | EngOilp | PGN | 0xFEEF | Cyclic | 500ms | FLOAT | RELEASED | 0.0.1 | Engine Oil Pressure in kPa (SPN 100). Resolution: 4kPa/bit, 0 offset |
| In | EngOilt1 | PGN | 0xFEEE | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Engine Oil Temperature 1 in °C (SPN 175). Resolution: 0.03125°C/bit, -273°C offset |
| In | EngOpState | PGN | 0xFD92 | Cyclic | 250ms | FLOAT | RELEASED | 0.0.1 | "This parameter is used to indicate the current state, or mode, of operation by the engine. This is a status parameter. … |
| In | EngPerLdAtCurrSpd | PGN | 0xF003 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Engine Load at Current Speed in Percent (SPN 92). Resolution: 1%/bit, 0 offset |
| In | EngRefTq | PGN | 0xFEE3 | Cyclic | 1000ms | array | IMPLEMENTED | 0.0.1 | SPN - 544, Engine Reference Torque. This parameter is the 100% reference value for all defined indicated engine torque p … |
| In | EngSpd | PGN | 0xF004 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Engine Speed in rpm (SPN 190). Resolution: 0.125 rpm/bit, 0 offset |
| In | EngStrtrMod | PGN | 0xF004 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Engine Starter Mode (SPN 1675) |
| In | EngThrPosPer | PGN | 0xFEF2 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Engine Throttle Position in Percent (SPN 51). Resolution: 0.4%/bit, 0 offset |
| In | EngTotalFuelUsed | PGN | 0xFD09 | Cyclic | 1000ms | DOUBLE | RELEASED | 0.0.1 | Accumulated amount of fuel used during vehicle operation. High resolution used for calculations and fleet management sys … |
| In | EngTotOperHrs | PGN | 0xFEE5 | Adhoc | - | FLOAT | RELEASED | 0.0.1 | Engine Total Hours of Operation in hours (hr) (SPN 247). Resolution: 0.05 hr/bit, 0 offset |
| In | EngTotRevolutions | PGN | 0xFEE5 | Adhoc | - | FLOAT | RELEASED | 0.0.1 | Engine Total Revolutions in revolutions (r) (SPN 249). Resolution: 1000 r/bit, 0 offset |
| In | EngTrbChOilt1 | PGN | 0xFEEE | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Engine Turbocharger Oil Temperature in °C(SPN 176). Resolution: 0.03125°C/bit, -273°C offset |
| In | EngTripFuel | PGN | 0xFD09 | Cyclic | 1000ms | DOUBLE | IMPLEMENTED | 0.0.1 | SPN: 5053, Engine Trip Fuel (High Resolution) Fuel consumed during all or part of a journey. High resolution used for ca … |
| In | EngTrqMod | PGN | 0xF004 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Engine Torque Mode (SPN 899) |
| In | ERC1_ElectronicRetarderController1 | PGN | 0xF000 | Cyclic | 100ms | array | IMPLEMENTED | 0.0.1 | Provides SPNs 900, 520, 1085 & 1667 of Electronic Retarder Controller 1 (PGN 61440) |
| In | FuLvlPer | PGN | 0xFEFC | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Fuel Level in Percent (SPN 96). Resolution: 0.4%/bit, 0 offset |
| In | FuLvlPer2 | PGN | 0xFEFC | Cyclic | 1000ms | FLOAT | IMPLEMENTED | 0.0.1 | Fuel Level in Percent (SPN 38). Resolution: 0.4%/bit, 0 offset |
| In | GndBasdMacDir | PGN | 0xFE49 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Ground-Based Machine Direction (SPN 1861, cp. A.7). |
| In | GndBasdMacDst | PGN | 0xFE49 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Ground-Based Machine Distance in m (SPN 1860, cp. A.6). Resolution: 0.001 m/bit, 0 offset. |
| In | GndBasdMacSpd | PGN | 0xFE49 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Ground-Based Machine Speed in m/s (SPN 1859, cp. A.5). Resolution: 0.001 m/s/bit, 0 offset; upper byte resolution = 0.25 … |
| In | HitchExistReasCodBitStFrnt | PGN | 0xFE46 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Hitch Exit Reason Code as Bit Status (SPN 5816, cp. A.19.13). Resolution: 64 states per 6 bit, 0 offset |
| In | HitchExistReasCodBitStRe | PGN | 0xFE45 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Hitch Exit Reason Code as Bit Status (SPN 5819 cp. A.19.14). Resolution: 64 states per 6 bit, 0 offset |
| In | HitchPosLimStFrnt | PGN | 0xFE46 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Hitch Position Limit Status (SPN 5150, cp.A.19.11) |
| In | HitchPosLimStRe | PGN | 0xFE45 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Hitch Position Limit Status (SPN 5151 cp. A.19.12) |
| In | HitchPosPerFrnt | PGN | 0xFE46 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Hitch Position in Percent (SPN 872, cp. A.19.1). Resolution: 0.4%/bit, 0 offset |
| In | HitchPosPerRe | PGN | 0xFE45 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Hitch Position in Percent (SPN 1873 cp. A.19.2). Resolution: 0.4%/bit, 0 offset |
| In | HitchwIndcnFrnt | PGN | 0xFE46 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Hitch in Work Indication (SPN 1876 cp. A.19.5) |
| In | HitchwIndcnRe | PGN | 0xFE45 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Hitch in Work Indication (SPN 1877 cp. A.19.6) |
| In | HVESS1 | PGN | 0xF090 | Cyclic | 20ms | array | DEVELOPED | 0.0.1 | High Voltage Energy Storage System Data 1 (PGN 61584 - 0xF090) SPNs: 5919: HVESS Voltage Level - HVESSVoltageLvl 5920: H … |
| In | HVESS2 | PGN | 0xF091 | Cyclic | 20ms | FLOAT | DEVELOPED | 0.0.1 | High Voltage Energy Storage System Data 2 (PGN: 61585 - 0xF091) SPN: 5921: HVESS Fast Update State of Charge : HVESSFast … |
| In | HydOilFltRstrnSwt | PGN | 0xFE68 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Hydraulic Oil Filter Restriction Switch (SPN 1713).. |
| In | HydOilLvlPer | PGN | 0xFE68 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Hydraulic Oil Level in Percent (SPN 2602). Resolution: 0.4%/bit, 0 offset |
| In | Hydt | PGN | 0xFE68 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Hydraulic Temperature in °C (SPN 1638). Resolution: 1°C/bit, -40°C offset |
| In | IdleOp | PGN | 0xFEDC | Adhoc | - | array | IMPLEMENTED | 0.0.1 | Engine Total Idle Hours, Accumulated time of operation of the engine while under idle conditions. |
| In | InstnsEngFuEco | PGN | 0xFEF2 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Engine Instantaneous Fuel Economy in in km/L (SPN 184). Resolution: 1/512km/L per bit, 0 offset |
| In | KeySwtSt | PGN | 0xFE48 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Key Switch State (SPN 1865, cp. A.11). |
| In | MaxActEngPerTrq | PGN | 0xF003 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Actual Maximum Available Engine Torque in Percent (SPN 3357). Resolution: 0.4%/bit, 0 offset |
| In | MaxTimeOfMinTractorPwr | PGN | 0xFE48 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Maximum Time of Tractor Power in min (SPN 1866, cp. A.12). Resolution: 1 min/bit, 0 offset |
| In | MaxVehSpdLmt | PGN | 0x00FEED | Cyclic | 10ms | INT | IMPLEMENTED | 0.0.1 | Maximum vehicle velocity allowed. SPN 74 |
| In | NavBasdVehSpd | PGN | 0xFEE8 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Navigation-Based Vehicle Speed in km/h (SPN 517). Resolution: 1/256 km/h per bit, 0 offset |
| In | NomLowrLnkFPerFrnt | PGN | 0xFE46 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Nominal Lower Link Force in Percent (SPN 1880, cp. A.19.9). Resolution: 0.8%/bit, -100% offset |
| In | NomLowrLnkFPerRe | PGN | 0xFE45 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Nominal Lower Link Force in Percent (SPN 1881 cp. A.19.10). Resolution: 0.8%/bit, -100% offset |
| In | OprDirReversed | PGN | 0xFE48 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Operator Direction Reversed (SPN 5244, cp. A.31). |
| In | PirchAg | PGN | 0xFEE8 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Pitch in degree (SPN 583). Resolution: 1/128 deg/bit, -200 deg offset |
| In | PrdcCrCtlSt | PGN | 0xF0D3 | Cyclic | 100ms | enum | IMPLEMENTED | 0.0.1 | SPN : 7317, Predictive Cruise Control State, Indicates the state of the PCC controller |
| In | PTOEcoModFrnt | PGN | 0xFE44 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Economy Mode (SPN 1891, A.20.11 ). |
| In | PTOEcoModRe | PGN | 0xFE43 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Economy Mode (SPN 1892 cp. A.20.12 ). |
| In | PTOEcoModReqStFrnt | PGN | 0xFE44 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Economy Mode Request Status (5154, A.20.21). |
| In | PTOEcoModReqStRe | PGN | 0xFE43 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Economy Mode Request Status (SPN 5158 cp. A.20.25). |
| In | PTOEngmtFrnt | PGN | 0xFE44 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Engagement (SPN 1888, A.20.7) |
| In | PTOEngmtRe | PGN | 0xFE43 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Engagement (SPN 2408 cp. A.20.8) |
| In | PTOEngmtReqStFrnt | PGN | 0xFE44 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Engagement Request Status (5152, A.20.19). |
| In | PTOEngmtReqStRe | PGN | 0xFE43 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Engagement Request Status (SPN 5156 cp. A.20.23). |
| In | PTOExistReasCodBitStFrnt | PGN | 0xFE44 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Exit Reason Code as Bit Status (SPN 5817, A.20.27). Resolution: 64 states per 6 bit, 0 offset |
| In | PTOExistReasCodBitStRe | PGN | 0xFE43 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Exit Reason Code as Bit Status (SPN 5820 cp. A.20.28). Resolution: 64 states per 6 bit, 0 offset |
| In | PTOModFrnt | PGN | 0xFE44 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Mode (SPN 1889, A.20.9) |
| In | PTOModRe | PGN | 0xFE43 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Mode (SPN 1890 cp. A.20.10) |
| In | PTOModReqStRe | PGN | 0xFE43 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Mode Request Status (SPN 5157 cp. A.20.24) |
| In | PTOModReqStRFrnt | PGN | 0xFE44 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Mode Request Status (SPN 5153, A.20.20). |
| In | PTOOutpShaftSpdFrnt | PGN | 0xFE44 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Output Shaft Speed in 1/min (and A.20.1). Resolution: 0.125 1/min/bit, 0 offset |
| In | PTOOutpShaftSpdRe | PGN | 0xFE43 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Output Shaft Speed in 1/min (cp. A.20.2). Resolution: 0.125 1/min/bit, 0 offset |
| In | PTOOutpShaftSpdSetPntFrnt | PGN | 0xFE44 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Output Shaft Speed Set Point in 1/min (A.20.3). Resolution: 0.125 1/min/bit, 0 offset |
| In | PTOOutpShaftSpdSetPntRe | PGN | 0xFE43 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Output Shaft Speed Set Point in 1/min (cp. A.20.4). Resolution: 0.125 1/min/bit, 0 offset |
| In | PTOShaftSpdLimStFrnt | PGN | 0xFE44 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Shaft Speed Limit Status (SPN 5155, A.20.22). |
| In | PTOShaftSpdLimStRe | PGN | 0xFE43 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | PTO Shaft Speed Limit Status (SPN 5159 cp. A.20.26). |
| In | RmtAccpedPos | PGN | 0xF003 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Remote Accelerator Pedal Position in Percent (SPN 974). Resolution: 0.4%/bit, 0 offset |
| In | RoadSpdLmtStatus | PGN | 0xF003 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Road Speed Limit Status |
| In | RoadSurft | PGN | 0xFEF5 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Road Surface Temperature in °C (SPN 79). Resolution: 0.03125 °C/bit, -273°C offset |
| In | SeatBltSwt | PGN | 0xE000 | Cyclic | 1000ms | INT | IMPLEMENTED | 0.0.1 | SPN : 1856, Seat Belt Switch, State of switch used to determine if Seat Belt is buckled |
| In | SLIBattPckSoc | PGN | 0xFCB6 | Cyclic | 1000ms | FLOAT | IMPLEMENTED | 0.0.1 | SPN : 5981, SLI Battery Pack State of Charge, Indicates the remaining charge of the battery pack used for starting the e … |
| In | SnSOpr | PGN | 0xFE48 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Implement Start/Stop Operations (SPN 5203, cp. A.25.2). |
| In | SrvDst | PGN | 0XFEC0 | Adhoc | - | INT | IMPLEMENTED | 0.0.1 | Service Distance, The distance which can be traveled by the vehicle before the next service inspection is required. A ne … |
| In | TachoVehSpd | PGN | 0xFE6C | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | (SPN: 1624) Speed of the vehicle registered by the tachograph. Data Length: 2 bytes Resolution: 1/256 km/h per bit, 0 of … |
| In | TchogrDriverState | PGN | 0xFE6C | Cyclic | 10ms | array | IMPLEMENTED | 0.0.1 | 1. Driver 1 working state (TCO1, PGN65132, SPN 1612) Rx 2. Driver 2 working state (TCO1, PGN65132, SPN 1613) Rx 3. Vehic … |
| In | TireAirLeakRate | PGN | 0xFEF4 | Cyclic | 10000ms | FLOAT | RELEASED | 0.0.1 | Tire Air Leakage Rate in Pa/s (SPN 2586). Resolution: 0.1 Pa/s per bit, 0 offset |
| In | TireAirpDetn | PGN | 0xFEF4 | Cyclic | 10000ms | FLOAT | RELEASED | 0.0.1 | Tire Air Pressure Detection (SPN 2587) |
| In | TireLocnBitSt | PGN | 0xFEF4 | Cyclic | 10000ms | FLOAT | RELEASED | 0.0.1 | Tire Location as bit states (SPN 929). Resolution: 256 states/8 bit, 0 offset |
| In | Tirep | PGN | 0xFEF4 | Cyclic | 10000ms | FLOAT | RELEASED | 0.0.1 | Tire Pressure in kPa (SPN 241). Resolution: 4 kPa/bit, 0 offset |
| In | Tiret | PGN | 0xFEF4 | Cyclic | 10000ms | FLOAT | RELEASED | 0.0.1 | Tire Temperature in °C (SPN 242). Resolution: 0.03125 °C/bit, -273°C offset |
| In | TotalVehDist | PGN | 0xFEC1 | Cyclic | 1000ms | LONG | RELEASED | 0.0.1 | Accumulated distance traveled by the vehicle during its operation. NOTE - See SPN 245 for alternate resolution. Data Len … |
| In | TotFuCns | PGN | 0xFEE9 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Total Fuel Consumption in 0.5 litres (SPN 250) |
| In | TotPTOHrs | PGN | 0xFEE7 | Adhoc | - | FLOAT | RELEASED | 0.0.1 | Total Power Takeoff Hours in hours (hr) (SPN 248). Resolution: 0.05 hr/bit, 0 offset |
| In | TotVehHrs | PGN | 0xFEE7 | Adhoc | - | FLOAT | RELEASED | 0.0.1 | Total Vehicle Hours in hours (hr) (SPN 246). Resolution: 0.05 hr/bit, 0 offset |
| In | TransmissionCurGear | PGN | 0x00F005 | Cyclic | 100ms | INT | IMPLEMENTED | 0.0.1 | The gear currently engaged in the transmission or the last gear engaged while the transmission is in the process of shif … |
| In | TripFuCns | PGN | 0xFEE9 | Adhoc | - | FLOAT | RELEASED | 0.0.1 | Trip Fuel Consumption in 0.5 litres (SPN 182) |
| In | VehAccRateLmtStatus | PGN | 0xF003 | Cyclic | 50ms | FLOAT | RELEASED | 0.0.1 | Vehicle Acceleration Rate Limit Status |
| In | VehDynStabyCtrl2 | PGN | 0xF009 | Cyclic | 10ms | array | IMPLEMENTED | 0.0.1 | Vehicle Dynamic Stability Control 2 SPN: 1807 - Steering Wheel Angle SPN: 1811 - Steering Wheel Turn Counter SPN: 1812 - … |
| In | VehEPwr1 | PGN | 0x00FEF7 | Cyclic | 1000ms | array | IMPLEMENTED | 0.0.1 | Vehicle Electrical Power 1 PGN 65271 1. Net Battery Current \| SPN 114 2. Battery Potential \| SPN 168 |
| In | Vehicle_Identification_Number | PGN | 0xFEEC | Adhoc | - | array | IMPLEMENTED | 0.0.1 | Vehicle Identification Number (VIN) as assigned by the vehicle manufacturer. |
| In | VehiclePosition | PGN | 0xFEF3 | Cyclic | 1000ms | GPS | RELEASED | 0.0.1 | J1939 based Vehicle Position Data Range : -210 to 211.1008122 deg Offset : -210 PGN : 65267 SPN : 584 and 585 DLC : 32bi … |
| In | WhlBasdMacDir | PGN | 0xFE48 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Wheel Based Machine Direction (SPN 1864, cp. A.10). |
| In | WhlBasdMacDst | PGN | 0xFE48 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Wheel Based Machine Distance in m (SPN 1863, cp. A.9). Resolution: 0.001 m/bit, 0 offset |
| In | WhlBasdMacSpd | PGN | 0xFE48 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Wheel Based Machine Speed in m/s (SPN 1862, cp. A.8). Resolution: 0.001 m/s/bit, 0 offset |
| In | WhlBasedVehSpd | PGN | 0xFEF1 | Cyclic | 100ms | FLOAT | RELEASED | 0.0.1 | Speed of the vehicle as calculated from wheel or tailshaft speed (SPN84) 1/256 km/h per bit, 0 offset |
| In | WinchOilpSwt | PGN | 0xFE68 | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Winch Oil Pressure Switch (SPN 1857). |
| In | WshrFldLvlPer | PGN | 0xFEFC | Cyclic | 1000ms | FLOAT | RELEASED | 0.0.1 | Washer Fluid Level in Percent (SPN 80). Resolution: 0.4%/bit, 0 offset |

## Signal Fields

### CrCtlCCVS

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| CCVS1_crCtlSetSpeed | INT | km/h | - |
| CCVS1_crCtlActive | INT | - | - |
| CCVS1_crCtlStates | INT | - | - |
| CCVS1_ParkingBrakeSwitch | INT | - | - |
| CCVS1_crCtlPauseSwitch | INT | - | - |
| CCVS1_crCtlEnableSwitch | INT | - | - |
| CCVS1_BrakeSwitch | INT | - | - |
| CCVS1_ClutchSwitch | INT | - | - |
| CCVS1_crCtlCoastSwitch | INT | - | - |
| CCVS1_crCtlResumeSwitch | INT | - | - |
| CCVS1_crCtlAccelerateSwitch | INT | - | - |

### Drivers_Identification_Number

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| SourceAddress | INT | - | - |
| Driver1 | STRING | - | - |
| Driver2 | STRING | - | - |

### EEC3

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| NomFricPerc | INT | % | - |
| EngDesOpSpd | FLOAT | rpm | - |
| EngDesOpSpdAsymtryAdjmt | INT | NA | - |
| EstimdEngParasitLoss | INT | % | - |
| AT1ExhGasMassFlowRate | FLOAT | kg/h | - |
| EngExh1Dewp | INT | NA | - |
| AT1ExhDewp | INT | NA | - |
| EngExh2Dewp | INT | NA | - |
| AT2ExhDewp | INT | NA | - |

### EngRefTq

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Source_Address | INT | - | - |
| Data | INT | - | - |

### ERC1_ElectronicRetarderController1

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| RtdrTrqMod | INT | - | - |
| RtdrActTrqPrc | INT | % | - |
| RtdrIntdTrqPrc | INT | % | - |
| RtdrReqBrkLght | INT | - | - |

### HVESS1

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| HVESSVoltageLvl | FLOAT | V | - |
| HVESSCurrent | FLOAT | A | - |

### IdleOp

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| EngTotldlHrs | FLOAT | h | - |
| EngTotldlFulUsd | FLOAT | L | - |

### TchogrDriverState

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| TCO1_Driver1State | INT | - | - |
| TCO1_Driver2State | INT | - | - |
| TCO1_VehMotion | INT | - | - |
| TCO1_Driver1TimeRelatedState | INT | - | - |
| TCO1_Driver1CardState | INT | - | - |
| TCO1_Driver2TimeRelatedState | INT | - | - |
| TCO1_Driver2CardState | INT | - | - |

### VehDynStabyCtrl2

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| SterWhlAg | DOUBLE | rad | - |
| SterWhlTurnCntr | INT | turn | - |
| SterWhlAgSnsrTyp | INT | NA | - |
| YawRate | DOUBLE | rad/s | - |
| LatAcc | DOUBLE | m/s2 | - |
| LgtAcc | DOUBLE | m/s2 | - |

### VehEPwr1

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| VEP1_NET_BATTERY_CURRENT | INT | A | - |
| VEP1_BATTERY_POTENTIAL | FLOAT | V | - |

### Vehicle_Identification_Number

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Source_Address | INT | - | - |
| Data | STRING | - | - |
