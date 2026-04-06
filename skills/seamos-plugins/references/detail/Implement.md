# Implement

- **Machine ID**: 351
- **Provider Class**: com.bosch.nevonex.implement.impl.ImplementProvider
- **Category**: Implement

## Interfaces

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | Actual_Applied_Preservative_Per_Yield_Mass | ISOBUS | DDI531 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This DDI shall describe the actual applied preservative per harvested yield mass. |
| In | Actual_Atmospheric_Pressure | ISOBUS | DDI386 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The Actual Atmospheric Pressure is the air pressure currently measured by the weather station. |
| In | Actual_Bale_Compression_Plunger_Load_N | ISOBUS | DDI548 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The actual bale compression plunger load expressed as Newton. |
| In | Actual_Bale_Compression_Plunger_Load_P | ISOBUS | DDI219 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The actual bale compression plunger load expressed as percentage. |
| In | Actual_Bale_Hydraulic_Pressure | ISOBUS | DDI216 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The actual value of the hydraulic pressure applied to the sides of the bale in the bale compression chamber. |
| In | Actual_Bale_Size | ISOBUS | DDI112 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Bale Size as length for a square baler or diameter for a round baler |
| In | Actual_Bale_Width | ISOBUS | DDI102 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Bale Width for square baler or round baler |
| In | Actual_Canopy_Height | ISOBUS | DDI520 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual height of the canopy above ground. |
| In | Actual_Chaffer_Clearance | ISOBUS | DDI247 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual separation distance between Chaffer elements. |
| In | Actual_Concave_Clearance | ISOBUS | DDI251 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual separation distance between Concave elements. |
| In | Actual_Cooling_Fluid_Temperature | ISOBUS | DDI526 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The actual temperature of the cooling fluid for the machine. |
| In | Actual_Cutting_drum_speed | ISOBUS | DDI331 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The actual speed of the cutting drum of a chopper |
| In | Actual_Diesel_Exhaust_Fluid_Tank_Content | ISOBUS | DDI395 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The actual content of the diesel exhaust fluid tank |
| In | Actual_Electrical_Current | ISOBUS | DDI558 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Electrical Current of Device Element |
| In | Actual_Electrical_Power | ISOBUS | DDI569 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Electrical Power of Device Element |
| In | Actual_Electrical_Resistance | ISOBUS | DDI567 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Electrical Resistance of Device Element |
| In | Actual_Engine_Speed | ISOBUS | DDI484 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual rotational speed of the engine. |
| In | Actual_Engine_Torque | ISOBUS | DDI502 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The current torque of the engine. |
| In | Actual_Flake_Size | ISOBUS | DDI364 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual size of the flake that is currently produced by the chamber. |
| In | Actual_Frequency | ISOBUS | DDI584 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Frequency of Device Element specified as Hz |
| In | Actual_Fuel_Tank_Content | ISOBUS | DDI394 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The actual content of the fuel tank |
| In | Actual_Grain_Kernel_Cracker_Gap | ISOBUS | DDI342 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The actual gap (distance) of the grain kernel cracker drums in a chopper |
| In | Actual_Gross_Weight | ISOBUS | DDI232 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Gross Weight value specified as mass |
| In | Actual_Header_Rotational_Speed_Status | ISOBUS | DDI238 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual status of the header rotational speed being above or below the threshold for in-work state. |
| In | Actual_Header_Speed | ISOBUS | DDI327 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The actual rotational speed of the header attachment of a chopper, mower or combine |
| In | Actual_Header_Working_Height_Status | ISOBUS | DDI237 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual status of the header being above or below the threshold height for the in-work state. |
| In | Actual_length_of_cut | ISOBUS | DDI177 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual length of cut for harvested material, e.g. Forage Harvester or Tree Harvester. |
| In | Actual_Net_Weight | ISOBUS | DDI229 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Net Weight value specified as mass |
| In | Actual_Normalized_Difference_Vegetative_Index_NDVI | ISOBUS | DDI153 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The Normalized Difference Vegetative Index (NDVI) computed from crop reflectances as the difference between NIR reflecta … |
| In | Actual_Percentage_Content | ISOBUS | DDI467 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Device Element Content specified as percent. |
| In | Actual_Prescription_Mode | ISOBUS | DDI288 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This DDE defines the actual source of the set point value used by the Control Function. This DDI shall be defined as DPD … |
| In | Actual_Preservative_Tank_Level | ISOBUS | DDI540 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The percentage level of the preservative tank. |
| In | Actual_Preservative_Tank_Volume | ISOBUS | DDI539 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The actual volume inside the preservative tank. |
| In | Actual_Product_Pressure | ISOBUS | DDI194 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Product Pressure is the measured pressure in the product flow system at the point of dispensing. |
| In | Actual_Protein_Content_ | ISOBUS | DDI406 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Protein content of a harvested crops |
| In | Actual_PTO_Speed | ISOBUS | DDI541 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Speed of the Power Take-Off (PTO) |
| In | Actual_PTO_Torque | ISOBUS | DDI551 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Torque of the Power Take-Off (PTO) |
| In | Actual_Pump_Output_Pressure | ISOBUS | DDI198 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Pump Output Pressure measured at the output of the solution pump. |
| In | Actual_relative_connector_angle | ISOBUS | DDI466 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The DDI Actual relative connector angle shall be placed in the device element of type connector in the DDOP of the TC-SC … |
| In | Actual_Seed_Singulation_Percentage | ISOBUS | DDI415 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Seed Singulation Percentage calculated from measured seed spacing using ISO 7256-1 "Quality of Feed Index" algori … |
| In | Actual_Seeding_Depth | ISOBUS | DDI57 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Seeding Depth of Device Element below soil surface, value increases with depth |
| In | Actual_Separation_Fan_Rotational_Speed | ISOBUS | DDI255 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual rotational speed of the fan used for separating product material from non product material. |
| In | Actual_Sieve_Clearance | ISOBUS | DDI243 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual separation distance between Sieve elements |
| In | Actual_Swathing_Width | ISOBUS | DDI346 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This is the width of the swath currently created by a raker. |
| In | Actual_Temperature | ISOBUS | DDI579 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Temperature of Device Element specified as milli Kelvin |
| In | Actual_Tillage_Depth | ISOBUS | DDI52 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Tillage Depth of Device Element below soil surface, value increases with depth. In case of a negative value the s … |
| In | Actual_Tillage_Disc_Gang_Angle | ISOBUS | DDI530 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Tillage Gang Angle is the pivot angle of the gangs for the device element. |
| In | Actual_Un_Loading_System_Status | ISOBUS | DDI240 | Cyclic | 10ms | array | RELEASED | 0.0.1 | Actual status of the Unloading and/or Loading system. This DDE covers both Unloading and Loading of the device element w … |
| In | Actual_Voltage | ISOBUS | DDI564 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Voltage of a Device Element |
| In | Actual_Working_Height | ISOBUS | DDI62 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Working Height of Device Element above crop or soil |
| In | Actual_Working_Length | ISOBUS | DDI226 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Working Length of a Device Element. |
| In | ActualBaleHeight | ISOBUS | DDI107 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Bale Height is only applicable to square baler |
| In | ActualControlStatus | NEVONEX | - | Cyclic | 10ms | enum | RELEASED | 0.0.1 | Control Status of the implement can be lost connection, normal operation, safemode explicit, safemode irrecoverable, saf … |
| In | ActualCountContent | ISOBUS | DDI78 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Device Element Content specified as count |
| In | ActualCulturalPractice | ISOBUS | DDI179 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This is used to define the current cultural practice which is performed by an individual device operation. |
| In | ActualMainValveState | NEVONEX | - | Cyclic | 10ms | BOOLEAN | RELEASED | 0.0.1 | Main Valve is a logical valve. Used for master control of all the valves of an implement. |
| In | ActualMassContent | ISOBUS | DDI75 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Device Element Content specified as mass |
| In | ActualPercentageCropDryMatter | ISOBUS | DDI314 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Percentage Crop Dry Matter expressed as parts per million |
| In | ActualSpeed | ISOBUS | DDI397 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The actual speed as measured on or used by a device for the execution of task based data |
| In | ActualVolumeContent | ISOBUS | DDI72 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Device Element Content specified as volume |
| In | ActualVolumeContent_tank | ISOBUS | DDI72 | Cyclic | 10ms | INT_ARRAY | RELEASED | 0.0.1 | Actual Device Element Content specified as volume |
| In | ActualWorkState | ISOBUS | DDI141 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Work State |
| In | AmbientTemperature | ISOBUS | DDI192 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Ambient temperature measured by a machine. Unit is milli-Kelvin (mK). |
| In | Apparent_Wind_Direction | ISOBUS | DDI383 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The apparent wind is the wind which is measured on a moving vehicle. It is the result of two motions: the actual true wi … |
| In | Apparent_Wind_Speed | ISOBUS | DDI384 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The apparent wind is the wind which is measured on a moving vehicle. It is the result of two motions: the actual true wi … |
| In | Applicationtotalcount | ISOBUS | DDI82 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Application specified as count |
| In | ApplicationTotalMass | ISOBUS | DDI81 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Application specified as mass in kilogram [kg] |
| In | ApplicationTotalMassingram | ISOBUS | DDI352 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Application specified as mass in gram [g] |
| In | Applicationtotalvolume | ISOBUS | DDI80 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Application specified as volume as liter [L] |
| In | ApplicationTotalVolume_in_milliliter | ISOBUS | DDI351 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Application specified as volume in milliliter [ml] |
| In | Average_Applied_Preservative_Per_Yield_Mass | ISOBUS | DDI538 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The average volume per mass for this task. |
| In | Average_Crop_Contamination | ISOBUS | DDI408 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average amount of dirt or foreign in a harvested crop |
| In | Average_Crop_Moisture | ISOBUS | DDI262 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Moisture of the harvested crop. This value is the average for a Task and may be reported as a total. |
| In | Average_Dry_Yield_Mass_Per_Area | ISOBUS | DDI359 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Yield expressed as mass per unit area, corrected for the reference moisture percentage DDI 184. This value is th … |
| In | Average_Dry_Yield_Mass_Per_Time | ISOBUS | DDI358 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Yield expressed as mass per unit time, corrected for the reference moisture percentage DDI 184. This value is th … |
| In | Average_Protein_Content | ISOBUS | DDI407 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average protein content in a harvested crop |
| In | Average_Seed_Multiple_Percentage | ISOBUS | DDI420 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Seed Multiple Percentage calculated from measured seed spacing using ISO 7256-1 "Multiples Index" algorithm. The … |
| In | Average_Seed_Singulation_Percentage | ISOBUS | DDI416 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Seed Singulation Percentage calculated from measured seed spacing using ISO 7256-1 "Quality of Feed Index" algor … |
| In | Average_Seed_Skip_Percentage | ISOBUS | DDI418 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Seed Skip Percentage calculated from measured seed spacing using ISO 7256-1 "Miss Index" algorithm. The value is … |
| In | Average_Seed_Spacing_Deviation | ISOBUS | DDI422 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Seed Spacing Deviation from setpoint seed spacing. The value is the average for a Task. |
| In | Average_Yield_Mass_Per_Area | ISOBUS | DDI263 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Yield expressed as mass per unit area, not corrected for the reference moisture percentage DDI 184. This value i … |
| In | Average_Yield_Mass_Per_Time | ISOBUS | DDI261 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Yield expressed as mass per unit time, not corrected for the reference moisture percentage DDI 184. This value i … |
| In | AverageCoefficient_Seed_Spacing_Percentage | ISOBUS | DDI424 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Coefficient of Variation of Seed Spacing Percentage calculated from measured seed spacing using ISO 7256-1 algor … |
| In | AveragePercentageCropDryMatter | ISOBUS | DDI315 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Percentage Crop Dry Matter expressed as parts per million. |
| In | bin_eti | ISOBUS | DDI178 | Cyclic | 10ms | INT_ARRAY | RELEASED | 0.0.1 | This DDI is used to get bin indexes under Implement level. Default value when zero bins : 65535 |
| In | bin_eti_count | ISOBUS | DDI178 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This DDI is used to enumerate and identify multiple device elements (DET) of the same type within one Device Description … |
| In | Chopper_Engagement_Total_Time | ISOBUS | DDI324 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated time while the chopping mechanism is engaged |
| In | Connector_Pivot_X_Offset | ISOBUS | DDI246 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | X direction offset of a connector pivot point relative to DRP. |
| In | ConnectorType | ISOBUS | DDI157 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Specification of the type of coupler. |
| In | Count_Per_Area_Crop_Loss | ISOBUS | DDI94 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Crop yield loss as count per area |
| In | Count_Per_Area_Yield | ISOBUS | DDI85 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Yield as count per area |
| In | Count_Per_Time_Crop_Loss | ISOBUS | DDI97 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Crop yield loss as count per time |
| In | Count_Per_Time_Yeild | ISOBUS | DDI88 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Yield as count per time |
| In | Crop_Contamination | ISOBUS | DDI100 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Dirt or foreign material in crop yield |
| In | Crop_Moisture | ISOBUS | DDI99 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Moisture in crop yield |
| In | Crop_Temperature | ISOBUS | DDI241 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Temperature of harvested crop |
| In | Default_Applied_Preservative_Per_Yield_Mass | ISOBUS | DDI533 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The default volume of preservative applied per harvested yield mass |
| In | Default_Bale_Height | ISOBUS | DDI108 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Default Bale Height is only applicable to square baler |
| In | Default_Bale_Size | ISOBUS | DDI113 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Default Bale Size as length for a square baler or diameter for a round baler |
| In | Default_Bale_Width | ISOBUS | DDI103 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Default Bale Width for square baler or round baler |
| In | Default_Electrical_Current | ISOBUS | DDI561 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Default electrical current of Device Element |
| In | Default_Electrical_Power | ISOBUS | DDI570 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Default Electrical Power of Device Element |
| In | Default_PTO_Speed | ISOBUS | DDI543 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The default Speed of the Power Take-Off (PTO) |
| In | Default_PTO_Torque | ISOBUS | DDI553 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The default Torque of the Power Take-Off (PTO) |
| In | Default_Revolutions_Per_Time | ISOBUS | DDI391 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Default Revolutions specified as count per time |
| In | Default_Seeding_Depth | ISOBUS | DDI58 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Default Seeding Depth of Device Element below soil surface, value increases with depth |
| In | Default_Temperature | ISOBUS | DDI582 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Default Temperature of Device Element specified as milli Kelvin |
| In | Default_Tillage_Depth | ISOBUS | DDI53 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Default Tillage Depth of Device Element below soil surface, value increases with depth. In case of a negative value the … |
| In | Default_Voltage | ISOBUS | DDI563 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Default Voltage of a Device Element |
| In | Default_Working_Height | ISOBUS | DDI63 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Default Working Height of Device Element above crop or soil |
| In | Default_Working_Width | ISOBUS | DDI68 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Default Working Width of Device Element |
| In | Delta_T | ISOBUS | DDI224 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The difference between dry bulb temperature and wet bulb temperature measured by a weather station in a treated field or … |
| In | DeviceInfo | NEVONEX | - | Cyclic | 10ms | array | RELEASED | 0.0.1 | All the attributes of DVC tag of DDOP |
| In | Diesel_Exhaust_Fluid_Tank_Percentage_Level | ISOBUS | DDI488 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The actual level of the Diesel Exhaust Fluid Tank in percent. |
| In | Dry_Mass_Per_Area_Yield | ISOBUS | DDI181 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Dry Mass Per Area Yield. |
| In | Dry_Mass_Per_Time_Yield | ISOBUS | DDI182 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Dry Mass Per Time Yield |
| In | Effective_Total_Diesel_Exhaust_Fluid_Consumption | ISOBUS | DDI318 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated total Diesel Exhaust Fluid consumption in working position. |
| In | Effective_Total_Fuel_Consumption | ISOBUS | DDI316 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated total fuel consumption in working position. |
| In | Effective_Total_Loading_Time | ISOBUS | DDI339 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total time needed in the current task to load a product such as crop. |
| In | Effective_Total_Unloading_Time | ISOBUS | DDI340 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total time needed in the current task to unload a product crop. |
| In | EffectiveTotalTime | ISOBUS | DDI119 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Time in working position |
| Out | Enable_Rate_Control | ISOBUS | DDI158 | Process | - | BOOLEAN | RELEASED | 0.0.1 | Set or Reset the prescription control state |
| Out | Enable_Section_Control | ISOBUS | DDI160 | Process | - | BOOLEAN | RELEASED | 0.0.1 | Set or Reset the section control state |
| Out | ForceSafeMode | NEVONEX | - | Process | - | BOOLEAN | RELEASED | 0.0.1 | FIL set all the sections to off and set the application rate to 0. |
| In | Front_PTO_hours | ISOBUS | DDI335 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The hours the Front PTO of the machine was running for the current Task |
| In | Fuel_Percentage_Level | ISOBUS | DDI491 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The actual level of the machine fuel tank in percent. |
| In | Function_or_Operation_Technique | ISOBUS | DDI350 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Function or Operation Technique DDE can be used to define the operation technique or functionality performed by a de … |
| In | GetReferencePosition | NEVONEX | - | Cyclic | 10ms | GPS | RELEASED | 0.0.1 | GPS Position of implement reference point without Look ahead |
| In | GNSS_Installation_Type | ISOBUS | DDI521 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The GNSS Installation Type DDE is used by the device to provide additional information about the type and location of th … |
| In | Gross_Weight_State | ISOBUS | DDI233 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Gross Weight State, 2 bits defined as: |
| In | Ground_Cover | ISOBUS | DDI550 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The Ground Cover as an amount of soil that is covered by plants |
| In | Hydraulic_Oil_Temperature | ISOBUS | DDI258 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Temperature of fluid in the hydraulic system. |
| In | Ineffective_Total_Diesel_Exhaust_Fluid_Consumption | ISOBUS | DDI319 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated total Diesel Exhaust Fluid consumption in non working position. |
| In | Ineffective_Total_Distance | ISOBUS | DDI118 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Distance out of working position |
| In | Ineffective_Total_Fuel_Consumption | ISOBUS | DDI317 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated total fuel consumption in non working position. |
| In | Ineffective_Total_Time | ISOBUS | DDI120 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Time out of working position |
| In | Instantaneous_Area_Per_Time_Capacity | ISOBUS | DDI151 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Area per time capacity |
| In | Instantaneous_Diesel_Exhst_Fluid_Cnsptn_per_Area | ISOBUS | DDI411 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Diesel Exhaust Fluid consumption per area |
| In | Instantaneous_Diesel_Exhst_Fluid_Cnsptn_per_Time | ISOBUS | DDI410 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Diesel Exhaust Fluid consumption per time |
| In | Instantaneous_Fuel_Consumption_per_Area | ISOBUS | DDI150 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Fuel consumption per area |
| In | InstantaneousFuelConsumption | ISOBUS | DDI149 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Fuel consumption per time |
| In | Last_Bale_Applied_Preservative | ISOBUS | DDI221 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total preservative applied to the most recently produced bale. |
| In | Last_Bale_Average_Bale_Compression_Plunger_Load | ISOBUS | DDI220 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The average bale compression plunger load for the most recently produced bale expressed as percentage. |
| In | Last_Bale_Average_Bale_Compression_Plunger_Load_N | ISOBUS | DDI549 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The average bale compression plunger load for the most recently produced bale expressed as newton. |
| In | Last_Bale_Average_Hydraulic_Pressure | ISOBUS | DDI217 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The average actual value of the hydraulic pressure applied to the sides of the bale in the bale compression chamber. Thi … |
| In | Last_Bale_Average_Moisture | ISOBUS | DDI212 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The average moisture in the most recently produced bale. |
| In | Last_Bale_Average_Strokes_per_Flake | ISOBUS | DDI213 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The number of baler plunger compression strokes per flake that has entered the bale compression chamber. This value is t … |
| In | Last_Bale_Capacity | ISOBUS | DDI528 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The capacity of the bale that leaves the machine. |
| In | Last_Bale_Density | ISOBUS | DDI361 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The bale density of the most recently produced bale. |
| In | Last_Bale_Dry_Mass | ISOBUS | DDI363 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The dry mass of the bale that has most recently been produced. This is the bale mass corrected for the average moisture … |
| In | Last_Bale_Flakes_per_Bale | ISOBUS | DDI211 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The number of flakes in the most recently produced bale. |
| In | Last_Bale_Lifetime_Count | ISOBUS | DDI519 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Lifetime Bale Count of the bale that leaves the machine. |
| In | Last_Bale_Mass | ISOBUS | DDI223 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The mass of the bale that has most recently been produced. |
| In | Last_Bale_Number_of_Subbales | ISOBUS | DDI482 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Number of smaller bales included in the latest produced bale. |
| In | Last_Bale_Size | ISOBUS | DDI360 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The bale size of the most recently produced bale. Bale Size as length for a square baler or diameter for a round baler. |
| In | Last_Bale_Tag_Number | ISOBUS | DDI222 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Last Bale Tag Number as a decimal number in the range of 0 to 4294967295. Note that the value of this DDI has the li … |
| In | Last_Event_Partner_ID_Device_Class | ISOBUS | DDI500 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This DDI should tell the Device Class of the “Partner” Device. |
| In | Last_Event_Partner_ID_Manufacturer_ID_Code | ISOBUS | DDI499 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Partner ID has to tell its Manufacturer, and the Manufacturer Numbers from SAE J1939 / ISO 11783 shall be used. |
| In | Last_Event_Partner_ID_Type | ISOBUS | DDI498 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Defines The Type of the Partner ID Device. See Attatchment for Definition. |
| In | Last_loaded_Count | ISOBUS | DDI462 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Last loaded Count value specified as count |
| In | Last_loaded_Volume | ISOBUS | DDI456 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Last loaded Volume value specified as volume |
| In | Last_loaded_Weight | ISOBUS | DDI320 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Last loaded Weight value specified as mass |
| In | Last_unloaded_Count | ISOBUS | DDI463 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Last unloaded Count value specified as count |
| In | Last_unloaded_Volume | ISOBUS | DDI457 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Last unloaded Volume value specified as volume |
| In | Last_unloaded_Weight | ISOBUS | DDI321 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Last unloaded Weight value specified as mass |
| In | Lifetime_Applied_Preservative | ISOBUS | DDI537 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total applied volume of preservative in the lifetime of the machine |
| In | Lifetime_Average_Fuel_Consumption_per_Area | ISOBUS | DDI278 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Average Fuel Consumption per Area of the device lifetime. |
| In | Lifetime_Average_Fuel_Consumption_per_Time | ISOBUS | DDI277 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Average Fuel Consumption per Time of the device lifetime. |
| In | Lifetime_Avg_Diesel_Exhst_Fluid_Cnsptn_per_Area | ISOBUS | DDI414 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Diesel Exhaust Fluid Consumption per Area over the entire lifetime of the device. |
| In | Lifetime_Avg_Diesel_Exhst_Fluid_Cnsptn_per_Time | ISOBUS | DDI413 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Diesel Exhaust Fluid Consumption per Time over the entire lifetime of the device. |
| In | Lifetime_Bale_Count | ISOBUS | DDI214 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The number of bales produced by a machine over its entire lifetime. This DDE value can not be set through the process da … |
| In | Lifetime_Chopping_Engagement_Total_Time | ISOBUS | DDI546 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Chopping Engagement Total Time of the device lifetime. |
| In | Lifetime_Diesel_Exhaust_Fluid_Consumption | ISOBUS | DDI412 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Accumulated Diesel Exhaust Fluid Consumption over the entire lifetime of the device. |
| In | Lifetime_Engine_Hours | ISOBUS | DDI493 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The total time, when the engine was running over the whole lifetime of the machine. |
| In | Lifetime_Front_PTO_hours | ISOBUS | DDI337 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The hours the Front PTO of the machine was running for the lifetime of the machine |
| In | Lifetime_Ineffective_Total_Distance | ISOBUS | DDI273 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Ineffective Total Distance of the device lifetime. |
| In | Lifetime_Ineffective_Total_Time | ISOBUS | DDI275 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Ineffective Total Time of the device lifetime. |
| In | Lifetime_Loaded_Total_Count | ISOBUS | DDI460 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Loaded Total Count of the device lifetime. |
| In | Lifetime_Loaded_Total_Mass | ISOBUS | DDI430 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Mass of the device lifetime. |
| In | Lifetime_loaded_Total_Volume | ISOBUS | DDI454 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire loaded Volume of the device lifetime. |
| In | Lifetime_Mesh_Bale_Total_Count | ISOBUS | DDI525 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire total number of mesh product units for which Net binding method was used during operation, of a device lifetime |
| In | Lifetime_Precut_Total_Count | ISOBUS | DDI285 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Precut Total Count of the device lifetime. |
| In | Lifetime_Rear_PTO_Hours | ISOBUS | DDI338 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The hours the Rear PTO of the machine was running for the lifetime of the machine |
| In | Lifetime_Threshing_Engagement_Total_Time | ISOBUS | DDI282 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Threshing Engagement Total Time of the device lifetime. |
| In | Lifetime_Twine_Bale_Total_Count | ISOBUS | DDI524 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire total number of twine bound product units for which Twine binding method was used during operation, of a device l … |
| In | Lifetime_Uncut_Total_Count | ISOBUS | DDI286 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Uncut Total Count of the device lifetime. |
| In | Lifetime_Unloaded_Total_Count | ISOBUS | DDI461 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Unloaded Total Count of the device lifetime. |
| In | Lifetime_Unloaded_Total_Mass | ISOBUS | DDI431 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Unloaded Total Mass of the device lifetime. |
| In | Lifetime_Unloaded_Total_Volume | ISOBUS | DDI455 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire unloaded Volume of the device lifetime. |
| In | Lifetime_Yield_Total_Count | ISOBUS | DDI270 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Count of the device lifetime. |
| In | Lifetime_Yield_Total_Dry_Mass | ISOBUS | DDI279 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Dry Mass of the device lifetime. |
| In | Lifetime_Yield_Total_Lint_Cotton_Mass | ISOBUS | DDI281 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Seed Cotton Mass of the device lifetime. |
| In | Lifetime_Yield_Total_Mass | ISOBUS | DDI269 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Mass of the device lifetime. |
| In | Lifetime_Yield_Total_Seed_Cotton_Mass | ISOBUS | DDI280 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Seed Cotton Mass of the device lifetime. |
| In | Lifetime_Yield_Total_Volume | ISOBUS | DDI268 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Volume of the device lifetime. |
| In | LifetimeApplicationTotalCount | ISOBUS | DDI267 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Application Total Count of the device lifetime. |
| In | LifetimeApplicationTotalMass | ISOBUS | DDI266 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Application Total Mass of the device lifetime. |
| In | LifetimeApplicationTotalVolume | ISOBUS | DDI325 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Application Total Volume of the device lifetime. |
| In | LifetimeEffectiveTotalDistance | ISOBUS | DDI272 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Total Distance of the device lifetime in working position. |
| In | LifetimeEffectiveTotalTime | ISOBUS | DDI274 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Effective Total Time of the device lifetime. |
| In | LifetimeFuelConsumption | ISOBUS | DDI276 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Entire Fuel Consumption of the device lifetime. |
| In | LifetimeTotalArea | ISOBUS | DDI271 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Total Area of the device lifetime. |
| In | LifetimeWorkingHours | ISOBUS | DDI215 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The number of working hours of a device element over its entire lifetime. |
| In | Lint_Cotton_Mass_Per_Area_Yield | ISOBUS | DDI186 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Lint cotton yield as mass per area. |
| In | Lint_Cotton_Mass_Per_Time_Yield | ISOBUS | DDI188 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Lint cotton yield as mass per time. |
| In | Lint_Turnout_Percentage | ISOBUS | DDI191 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Percent of lint in the seed cotton. |
| In | Load_Identification_Number | ISOBUS | DDI322 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Load Identification Number as a decimal number in the range of 0 to 4294967295. Note that the value of this DDI has … |
| In | Loaded_Total_Count | ISOBUS | DDI458 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Loads specified as count |
| In | Loaded_Total_Mass | ISOBUS | DDI428 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Loads specified as mass, not corrected for the reference moisture percentage DDI 184. |
| In | Loaded_Total_Volume | ISOBUS | DDI452 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Loaded Volume specified as volume |
| In | Log_Count | ISOBUS | DDI147 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Log Counter, may be used to control data log record generation on a Task Controller |
| In | MainValveOffLatency | ISOBUS | DDI206 | Adhoc | - | INT | RELEASED | 0.0.1 | "Latency of Main Valve. Main Valve is a logical valve and it is used for master control of all the valves of an implemen … |
| In | MainValveOnLatency | ISOBUS | DDI205 | Adhoc | - | INT | RELEASED | 0.0.1 | "Latency of Main Valve. Main Valve is a logical valve and it is used for master control of all the valves of an implemen … |
| In | Mass_Per_Area_Crop_Loss | ISOBUS | DDI93 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Crop yield loss as mass per area |
| In | Mass_Per_Area_Yield | ISOBUS | DDI84 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Yield as mass per area |
| In | Mass_Per_Time_Crop_Loss | ISOBUS | DDI96 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Crop yield loss as mass per time |
| In | Mass_Per_Time_Yield | ISOBUS | DDI87 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Yield as mass per time |
| In | Maximum_Applied_Preservative_Per_Yield_Mass | ISOBUS | DDI535 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The maximum volume, the preservative system can apply to the harvested yield in a controled way |
| In | Maximum_Bale_Height | ISOBUS | DDI110 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Bale Height is only applicable to square baler |
| In | Maximum_Bale_Hydraulic_Pressure | ISOBUS | DDI477 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The maximum value of the hydraulic pressure applied to the sides of the bale in the bale compression chamber. |
| In | Maximum_Bale_Size | ISOBUS | DDI115 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Bale Size as length for a square baler or diameter for a round baler |
| In | Maximum_Bale_Width | ISOBUS | DDI105 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Bale Width for square baler or round baler |
| In | Maximum_Chaffer_Clearance | ISOBUS | DDI249 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum separation distance between Chaffer elements. |
| In | Maximum_Concave_Clearance | ISOBUS | DDI253 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum separation distance between Concave elements. |
| In | Maximum_Cutting_drum_speed | ISOBUS | DDI333 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The maximum speed of the cutting drum of a chopper |
| In | Maximum_Diesel_Exhaust_Fluid_Tank_Content | ISOBUS | DDI489 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This value describes the maximum ammount of Diesel Exhaust fluid, that can be filled into the tank of the machine |
| In | Maximum_Electrical_Current | ISOBUS | DDI560 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Maximum electrical Current of Device Element |
| In | Maximum_Electrical_Power | ISOBUS | DDI571 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Maximum Electrical Power of Device Element |
| In | Maximum_Engine_Speed | ISOBUS | DDI486 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The maximum of the rotational speed of the engine. |
| In | Maximum_Engine_Torque | ISOBUS | DDI504 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The maximum value of the engine torque |
| In | Maximum_Flake_Size | ISOBUS | DDI480 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum size of the flake that can be produced by the chamber. |
| In | Maximum_Frequency | ISOBUS | DDI586 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Maximum Frequency of Device Element specified as Hz |
| In | Maximum_Fuel_Tank_Content | ISOBUS | DDI490 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This value describes the maximum ammount of fuel that can be filled into the machines Fuel tank. |
| In | Maximum_Grain_Kernel_Cracker_Gap | ISOBUS | DDI344 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The maximum gap (distance) of the grain kernel cracker drums in a chopper |
| In | Maximum_Gross_Weight | ISOBUS | DDI235 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Gross Weight specified as mass. |
| In | Maximum_Header_Speed | ISOBUS | DDI329 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The maximum rotational speed of the header attachment of a chopper, mower or combine |
| In | Maximum_Length_of_Cut | ISOBUS | DDI474 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Maximum length of cut for harvested material, e.g. Forage Harvester or Tree Harvester. |
| In | Maximum_Product_Pressure | ISOBUS | DDI196 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Maximum Product Pressure in the product flow system at the point of dispensing. |
| In | Maximum_PTO_Speed | ISOBUS | DDI545 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The maximum Speed of the Power Take-Off (PTO) |
| In | Maximum_PTO_Torque | ISOBUS | DDI555 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The maximum Torque of the Power Take-Off (PTO) |
| In | Maximum_Pump_Output_Pressure | ISOBUS | DDI200 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Maximum Pump Output Pressure for the output pressure of the solution pump. |
| In | Maximum_Relative_Yield_Potential | ISOBUS | DDI313 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum potential yield expressed as percentage. |
| In | Maximum_Revolutions_Per_Time | ISOBUS | DDI393 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Maximum Revolutions specified as count per time |
| In | Maximum_Seeding_Depth | ISOBUS | DDI60 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Seeding Depth of Device Element below soil surface, value increases with depth |
| In | Maximum_Separation_Fan_Rotational_Speed | ISOBUS | DDI257 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Maximum rotational speed of the fan used for separating product material from non product material. |
| In | Maximum_Sieve_Clearance | ISOBUS | DDI245 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum separation distance between Sieve elements. |
| In | Maximum_Speed | ISOBUS | DDI399 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The maximum speed that can be specified in a process data variable for communication between farm management information … |
| In | Maximum_Swathing_Width | ISOBUS | DDI348 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This is the maximum with of the swath the raker can create. |
| In | Maximum_Temperature | ISOBUS | DDI581 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Temperature of Device Element specified as milli Kelvin |
| In | Maximum_Tillage_Depth | ISOBUS | DDI55 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Tillage Depth of Device Element below soil surface, value increases with depth. In case of a negative value the … |
| In | Maximum_Voltage | ISOBUS | DDI566 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Maximum Voltage of a Device Element |
| In | Maximum_Working_Height | ISOBUS | DDI65 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Working Height of Device Element above crop or soil |
| In | Maximum_Working_Length | ISOBUS | DDI228 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Working Length of Device Element. |
| In | MaximumCountContent | ISOBUS | DDI79 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Device Element Content specified as count |
| In | MaximumMassContent | ISOBUS | DDI76 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Device Element Content specified as mass |
| In | MaximumVolumeContent | ISOBUS | DDI73 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Maximum Device Element Content specified as volume |
| In | MaximumVolumeContent_tank | ISOBUS | DDI73 | Cyclic | 10ms | INT_ARRAY | RELEASED | 0.0.1 | Maximum Device Element Content specified as volume |
| In | Mesh_Bale_Total_Count | ISOBUS | DDI523 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total number of mesh product units for which Net binding method was used during operation. |
| In | Minimum_Applied_Preservative_Per_Yield_Mass | ISOBUS | DDI534 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The minimum setable value, the preservative system is able to control the flow of preservative. |
| In | Minimum_Bale_Height | ISOBUS | DDI109 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum Bale Height is only applicable to square baler |
| In | Minimum_Bale_Hydraulic_Pressure | ISOBUS | DDI476 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The minimum value of the hydraulic pressure applied to the sides of the bale in the bale compression chamber. |
| In | Minimum_Bale_Size | ISOBUS | DDI114 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum Bale Size as length for a square baler or diameter for a round baler |
| In | Minimum_Bale_Width | ISOBUS | DDI104 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum Bale Width for square baler or round baler |
| In | Minimum_Chaffer_Clearance | ISOBUS | DDI248 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum separation distance between Chaffer elements. |
| In | Minimum_Concave_Clearance | ISOBUS | DDI252 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum separation distance between Concave elements. |
| In | Minimum_Cutting_drum_speed | ISOBUS | DDI332 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The minimum speed of the cutting drum of a chopper |
| In | Minimum_Electrical_Current | ISOBUS | DDI559 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Minimum electrical Current of Device Element |
| In | Minimum_Electrical_Power | ISOBUS | DDI572 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Minimum Electrical Power of Device Element |
| In | Minimum_Engine_Speed | ISOBUS | DDI485 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The minimum of the rotational speed of the engine. |
| In | Minimum_Engine_Torque | ISOBUS | DDI503 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The minimum value of the engine torque |
| In | Minimum_Flake_Size | ISOBUS | DDI479 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum size of the flake that can be produced by the chamber. |
| In | Minimum_Frequency | ISOBUS | DDI585 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Minimum Frequency of Device Element specified as Hz |
| In | Minimum_Grain_Kernel_Cracker_Gap | ISOBUS | DDI343 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The minimum gap (distance) of the grain kernel cracker drums in a chopper |
| In | Minimum_Gross_Weight | ISOBUS | DDI234 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum Gross Weight specified as mass. |
| In | Minimum_Header_Speed | ISOBUS | DDI328 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The minimum rotational speed of the header attachment of a chopper, mower or combine |
| In | Minimum_length_of_cut | ISOBUS | DDI473 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Minimum length of cut for harvested material, e.g. Forage Harvester or Tree Harvester. |
| In | Minimum_Product_Pressure | ISOBUS | DDI195 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Minimun Product Pressure in the product flow system at the point of dispensing. |
| In | Minimum_PTO_Speed | ISOBUS | DDI544 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The minimum Speed of the Power Take-Off (PTO) |
| In | Minimum_PTO_Torque | ISOBUS | DDI554 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The minimum Torque of the Power Take-Off (PTO) |
| In | Minimum_Pump_Output_Pressure | ISOBUS | DDI199 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Minimum Pump Output Pressure for the output pressure of the solution pump. |
| In | Minimum_Relative_Yield_Potential | ISOBUS | DDI312 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum potential yield expressed as percentage. |
| In | Minimum_Revolutions_Per_Time | ISOBUS | DDI392 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Minimum Revolutions specified as count per time |
| In | Minimum_Seeding_Depth | ISOBUS | DDI59 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum Seeding Depth of Device Element below soil surface, value increases with depth |
| In | Minimum_Separation_Fan_Rotational_Speed | ISOBUS | DDI256 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Minimum rotational speed of the fan used for separating product material from non product material. |
| In | Minimum_Sieve_Clearance | ISOBUS | DDI244 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimal separation distance between Sieve elements |
| In | Minimum_Swathing_Width | ISOBUS | DDI347 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This is the minimum swath width the raker can create. |
| In | Minimum_Temperature | ISOBUS | DDI580 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum Temperature of Device Element specified as milli Kelvin |
| In | Minimum_Tillage_Depth | ISOBUS | DDI54 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum Tillage Depth of Device Element below soil surface, value increases with depth. In case of a negative value the … |
| In | Minimum_Voltage | ISOBUS | DDI565 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Minimum Voltage of a Device Element |
| In | Minimum_Working_Height | ISOBUS | DDI64 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum Working Height of Device Element above crop or soil |
| In | Minimum_Working_Length | ISOBUS | DDI227 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum Working Length of Device Element. |
| In | Minimum_Working_Width | ISOBUS | DDI69 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Minimum Working Width of Device Element |
| In | MntrdSetpoint_Applied_Preservative_Per_Yield_Mass | ISOBUS | DDI532 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The desired volume of preservative per harvested yield mass |
| In | Monitored_Physical_Setpoint_Time_Latency_tank | ISOBUS | DDI142 | Cyclic | 10ms | INT_ARRAY | RELEASED | 0.0.1 | The Setpoint Value Latency Time is the time lapse between the moment of receival of a setpoint value command by the work … |
| In | MonitoredSetpnt_SeedingDepth | ISOBUS | DDI56 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Seeding Depth of Device Element below soil surface, value increases with depth |
| In | MonitoredSetpnt_TillageDepth | ISOBUS | DDI51 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Tillage Depth of Device Element below soil surface, value increases with depth. In case of a negative value the … |
| In | MonitoredSetpnt_WorkingHeight | ISOBUS | DDI61 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Working Height of Device Element above crop or soil |
| In | MonitoredSetpnt_WorkingLength | ISOBUS | DDI225 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Working Length of Device Element. |
| In | MonitoredSetpnt_WorkingWidth | ISOBUS | DDI66 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Working Width of Device Element |
| In | MonitoredSetpoint_Bale_Compression_Plunger_Load_N | ISOBUS | DDI547 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The setpoint bale compression plunger load expressed as Newton. |
| In | MonitoredSetpoint_Bale_Compression_Plunger_Load_P | ISOBUS | DDI218 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The setpoint bale compression plunger load expressed as percentage |
| In | MonitoredSetpoint_Bale_Height | ISOBUS | DDI106 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Bale Height is only applicable to square baler |
| In | MonitoredSetpoint_Bale_Hydraulic_Pressure | ISOBUS | DDI475 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The setpoint value of the hydraulic pressure applied to the sides of the bale in the bale compression chamber. |
| In | MonitoredSetpoint_Bale_Size | ISOBUS | DDI111 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Bale Size as length for a square baler or diameter for a round baler |
| In | MonitoredSetpoint_Bale_Width | ISOBUS | DDI101 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Bale Width for square baler or round baler |
| In | MonitoredSetpoint_Chaffer_Clearance | ISOBUS | DDI246 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint separation distance between Chaffer elements. |
| In | MonitoredSetpoint_Concave_Clearance | ISOBUS | DDI250 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint separation distance between Concave elements. |
| In | MonitoredSetpoint_Cutting_drum_speed | ISOBUS | DDI330 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The setpoint speed of the cutting drum of a chopper |
| In | MonitoredSetpoint_Electrical_Current | ISOBUS | DDI557 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint electrical Current of a Device Element |
| In | MonitoredSetpoint_Electrical_Power | ISOBUS | DDI568 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Electrical Power of Device Element |
| In | MonitoredSetpoint_Engine_Speed | ISOBUS | DDI483 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The setpoint of the rotational speed of the engine. |
| In | MonitoredSetpoint_Engine_Torque | ISOBUS | DDI501 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The setpoint of the engine torque. |
| In | MonitoredSetpoint_Flake_Size | ISOBUS | DDI478 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint size of the flake to be produced by the chamber. |
| In | MonitoredSetpoint_Frequency | ISOBUS | DDI583 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Frequency of Device Element specified as Hz |
| In | MonitoredSetpoint_Header_Speed | ISOBUS | DDI326 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The setpoint rotational speed of the header attachment of a chopper, mower or combine |
| In | MonitoredSetpoint_Length_of_Cut | ISOBUS | DDI472 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint length of cut for harvested material, e.g. Forage Harvester or Tree Harvester. |
| In | MonitoredSetpoint_Net_Weight | ISOBUS | DDI231 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Net Weight value. |
| In | MonitoredSetpoint_Number_of_Subbales | ISOBUS | DDI481 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Number of smaller bales that shall be included in one bigger bale. |
| In | MonitoredSetpoint_Prescription_Mode | ISOBUS | DDI287 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This DDE defines the source of the Task Controller set point value sent to the Control Function. This DDI shall be defin … |
| In | MonitoredSetpoint_PTO_Speed | ISOBUS | DDI542 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The desired Speed of the Power Take-Off (PTO) |
| In | MonitoredSetpoint_PTO_Torque | ISOBUS | DDI552 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The desired Torque of the Power Take-Off (PTO) |
| In | MonitoredSetpoint_Separation_Fan_Rotational_Speed | ISOBUS | DDI254 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint rotational speed of the fan used for separating product material from non product material. |
| In | MonitoredSetpoint_Sieve_Clearance | ISOBUS | DDI242 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint separation distance between Sieve elements |
| In | MonitoredSetpoint_Speed | ISOBUS | DDI396 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The setpoint speed that can be specified in a process data variable for communication between farm management informatio … |
| In | MonitoredSetpoint_Temperature | ISOBUS | DDI578 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Temperature of Device Element specified as milli Kelvin |
| In | MonitoredSetpoint_Tillage_Disc_Gang_Angle | ISOBUS | DDI529 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Tillage Gang Angle is the pivot angle of the gangs for the device element |
| In | MonitoredSetpoint_Voltage | ISOBUS | DDI562 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Voltage of a Device Element |
| In | MonitoredSetpointCountContent | ISOBUS | DDI77 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Device Element Content specified as count |
| In | MonitoredSetpointMassContent | ISOBUS | DDI74 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Machine Element Content specified as mass |
| In | MonitoredSetpointProductPressure | ISOBUS | DDI193 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Product Pressure to adjust the pressure of the product flow system at the point of dispensing. |
| In | MonitoredSetpointVolumeContent | ISOBUS | DDI71 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Device Element Content specified as volume |
| In | MonitoredSetpointWorkState | ISOBUS | DDI289 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Control command counterparts to the Work State DDI (141). |
| In | MonitoredTramlineSetpointControlLevel | ISOBUS | DDI506 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Tramline Control capability of the Task Controller that is used with the appropriate Implement. |
| In | MSL_Atmospheric_Pressure | ISOBUS | DDI385 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The atmospheric pressure MSL (Mean Sea Level) is the air pressure related to mean sea level. |
| In | Name | NEVONEX | - | Cyclic | 10ms | STRING | RELEASED | 0.0.1 | Brand Name of Implement |
| In | Net_Weight_State | ISOBUS | DDI230 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Net Weight State, 2 bits defined as: |
| In | Operating_Hours_Since_Last_Sharpening | ISOBUS | DDI334 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This value describes the working hours since the last sharpening of the cutting device. |
| In | Percentage_Crop_Loss | ISOBUS | DDI98 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Crop yield loss |
| In | Physical_Object_Height | ISOBUS | DDI156 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Height of device element (dimension along the Z-axis) |
| In | Physical_Object_Length | ISOBUS | DDI154 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Length of device element (dimension along the X-axis) |
| In | Physical_Object_Width | ISOBUS | DDI155 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Width of device element (dimension along the Y-axis) |
| In | PhysicalActualValueTimeLatency | ISOBUS | DDI143 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Value Latency Time |
| In | PhysicalActualValueTimeLatency_tank | ISOBUS | DDI143 | Cyclic | 10ms | INT_ARRAY | RELEASED | 0.0.1 | Actual Value Latency Time |
| In | Pitch_Angle | ISOBUS | DDI146 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Pitch Angle of a DeviceElement |
| In | Precut_Total_Count | ISOBUS | DDI283 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total number of pre-cutted product units produced by a device during an operation. |
| In | PrescriptionControlState | ISOBUS | DDI158 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual state of the prescription system |
| In | Present_Weather_Conditions | ISOBUS | DDI556 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | DDI to document the current weather conditions. Meaning of values: |
| In | Previous_Rainfall | ISOBUS | DDI587 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | DDI to document past rainfall conditions. |
| In | Product_Density_Mass_PerCount | ISOBUS | DDI122 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Product Density as mass per count |
| In | Product_Density_Volume_Per_Count | ISOBUS | DDD123 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Product_Density_Volume_Per_Count |
| In | ProductDensity | ISOBUS | DDI121 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Product Density as mass per volume |
| In | Rear_PTO_hours | ISOBUS | DDI336 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The hours the Rear PTO of the machine was running for the current Task |
| Out | RecoverSafeMode | NEVONEX | - | Process | - | BOOLEAN | RELEASED | 0.0.1 | Recovery from Safe mode. Application can request FIL to come out of safemode. This is one out of 2 conditions to come ou … |
| In | Reference_Moisture_For_Dry_Mass | ISOBUS | DDI184 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Moisture percentage used for the dry mass |
| In | Relative_Humidity | ISOBUS | DDI209 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Ambient humidty measured by a weather station in a treated field or on the application implement. |
| In | Relative_Yield_Potential | ISOBUS | DDI311 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Relative yield potential provided by a FMIS or a sensor or entered by the operator for a certain task expressed as perce … |
| In | RemainingArea | ISOBUS | DDI265 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Remaining Area of a field, which is calculated from the total area and the processed area. |
| In | Roll_Angle | ISOBUS | DDI145 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Roll Angle of a DeviceElement |
| In | SectionControlState | ISOBUS | DDI160 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual state of section control |
| In | Seed_Cotton_Mass_Per_Area_Yield | ISOBUS | DDI185 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Seed cotton yield as mass per area, not corrected for a possibly included lint percantage. |
| In | Seed_Cotton_Mass_Per_Time_Yield | ISOBUS | DDI187 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Seed cotton yield as mass per time, not corrected for a possibly included lint percantage. |
| Out | SetAllSectionValveOpen | NEVONEX | - | Process | - | BOOLEAN | RELEASED | 0.0.1 | Set All Section Valve in the boom (On/Off) |
| Out | SetMainValveOpen | NEVONEX | - | Process | - | BOOLEAN | RELEASED | 0.0.1 | Used to control all valves of an implement. |
| Out | SetSafeModeTimeout | NEVONEX | - | Process | - | INT | RELEASED | 0.0.1 | Set the timeout between set application rate calls. If FIL do not see calls within this rate watchdog timeout happens an … |
| In | Sky_conditions | ISOBUS | DDI210 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The current sky conditions during operation. The METAR format and its abbrivations is used as follows to define the sky … |
| In | SpeedSource | ISOBUS | DDI400 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Speed Source that the device uses to report actual speed and to process the setpoint, minimum and maximum speeds. |
| In | Thresher_Engagement_Total_Time | ISOBUS | DDI236 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated time while the threshing mechanism is engaged |
| In | Total_Applied_Preservative | ISOBUS | DDI536 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total volume of applied preservative in this task. |
| In | Total_Bale_Length | ISOBUS | DDI362 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Gives the total baled meters during a task. This is calculated as the sum of the lengths of all knotted bales (square ba … |
| In | Total_Diesel_Exhaust_Fluid_Consumption | ISOBUS | DDI409 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Diesel Exhaust Fluid Consumption as a Task Total. |
| In | Total_Electrical_Energy | ISOBUS | DDI573 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Accumulated Electrical Energy Consumption as a Task Total. |
| In | Total_Engine_Hours | ISOBUS | DDI492 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The total time the engine was running when the task was active. |
| In | Total_Revolutions_in_Complete_Revolutions | ISOBUS | DDI388 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Revolutions specified as completed integer revolutions |
| In | Total_Revolutions_in_Fractional_Revolutions | ISOBUS | DDI387 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Accumulated Revolutions specified with fractional revolutions |
| In | TotalApplicationofAmmonium | ISOBUS | DDI354 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated application of ammonium [NH4] specified as gram [g] |
| In | TotalApplicationofDryMatter | ISOBUS | DDI357 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated application of dry matter in kilogram [kg]. Dry matter measured at zero percent of moisture |
| In | TotalApplicationofNitrogen | ISOBUS | DDI353 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated application of nitrogen [N2] specified as gram [g] |
| In | TotalApplicationofPhosphor | ISOBUS | DDI355 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated application of phosphor (P2O5) specified as gram [g] |
| In | TotalApplicationofPotassium | ISOBUS | DDI356 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated application of potassium (K2) specified as gram [g] |
| In | TotalAreaPlanted | ISOBUS | DDI116 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Area |
| In | TotalAreaPlantedhectare | ISOBUS | DDI116 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Accumulated Area in Hectare |
| In | TotalDistance | ISOBUS | DDI117 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Distance in working position |
| In | TotalFuelConsumption | ISOBUS | DDI148 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Fuel Consumption as Counter |
| In | Tramline_Overdosing_Rate | ISOBUS | DDI516 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Overdosing Rate for the rows adjacent to the Tramline Track. |
| In | TramlineControlLevel | ISOBUS | DDI505 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Tramline Control capability of the Implement. |
| In | True_Rotation_Point_Y_Offset | ISOBUS | DDI307 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Y direction offset of the device rotation point relative to the DRP. |
| In | TrueRotationPointXoffset | ISOBUS | DDI306 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | X direction offset of the device rotation point relative to the DRP |
| In | Twine_Bale_Total_Count | ISOBUS | DDI522 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total number of twine bound product units for which Twine binding method was used during operation. |
| In | Type | NEVONEX | - | Cyclic | 10ms | enum | RELEASED | 0.0.1 | Type of Implement |
| In | Uncut_Total_Count | ISOBUS | DDI284 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total number of un-cutted product units produced by a device during an operation. |
| In | Unload_Identification_Number | ISOBUS | DDI323 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Unload Identification Number as a decimal number in the range of 0 to 2147483647. Note that the value of this DDI ha … |
| In | Unloaded_Total_Count | ISOBUS | DDI459 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Unloaded specified as count |
| In | Unloaded_Total_Mass | ISOBUS | DDI429 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Unloads specified as mass, not corrected for the reference moisture percentage DDI 184. |
| In | Unloaded_Total_Volume | ISOBUS | DDI453 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Unloaded Volume specified as volume |
| In | Volume_Per_Area_Crop_Loss | ISOBUS | DDI92 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Crop yield loss as volume per area |
| In | Volume_Per_Area_Yield | ISOBUS | DDI83 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Yield as volume per area |
| In | Volume_Per_Time_Crop_Loss | ISOBUS | DDI95 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Crop yield loss as volume per time |
| In | Volume_Per_Time_Yield | ISOBUS | DDI86 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | yeild as volume per time |
| In | WindDirection | ISOBUS | DDI208 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Wind direction measured in the treated field at the beginning of operations or on the application implement during opera … |
| In | WindSpeed | ISOBUS | DDI207 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Measured in the treated field at the beginning of operations or on the application implement during operations. |
| In | Yaw_Angle | ISOBUS | DDI144 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Pivot / Yaw Angle of a DeviceElement |
| In | Yield_Hold_Status | ISOBUS | DDI239 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Status indicator for the yield measurement system. When enabled/on, the measurements from the yield measurement system a … |
| In | Yield_Lag_Ignore_Time | ISOBUS | DDI259 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Amount of time to ignore yield data, starting at the transition from the in-work to the out-of-work state. During this t … |
| In | Yield_Lead_Ignore_Time | ISOBUS | DDI260 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Amount of time to ignore yield data, starting at the transition from the out-of-work to the in-work state. During this t … |
| In | Yield_Total_Count | ISOBUS | DDI91 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Yield specified as count |
| In | Yield_Total_Lint_Cotton_Mass | ISOBUS | DDI190 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated yield specified as lint cotton mass. |
| In | Yield_Total_Seed_Cotton_Mass | ISOBUS | DDI189 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated yield specified as seed cotton mass, not corrected for a possibly included lint percantage. |
| In | Yield_Total_Volume | ISOBUS | DDI89 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Yield specified as volume |
| In | YieldTotalDryMass | ISOBUS | DDI183 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Yield specified as dry mass. |
| In | YieldTotalMass | ISOBUS | DDI90 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Yield specified as mass |

### Boom (Machine ID: 602)

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | Actual_Chaffer_Clearance_boom | ISOBUS | DDI247 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual separation distance between Chaffer elements. |
| In | Actual_Concave_Clearance_boom | ISOBUS | DDI251 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual separation distance between Concave elements. |
| In | Actual_Downforce_as_Force_boom | ISOBUS | DDI427 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Downforce as Force |
| In | Actual_Downforce_Pressure_boom | ISOBUS | DDI366 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Downforce as Pressure |
| In | Actual_Header_Rotational_Speed_Status_boom | ISOBUS | DDI238 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual status of the header rotational speed being above or below the threshold for in-work state. |
| In | Actual_Header_Working_Height_Status_boom | ISOBUS | DDI237 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual status of the header being above or below the threshold height for the in-work state. |
| In | Actual_Percentage_Application_Rate_boom | ISOBUS | DDI308 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Application Rate expressed as percentage |
| In | Actual_Preservative_Tank_Level_boom | ISOBUS | DDI540 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The percentage level of the preservative tank. |
| In | Actual_Preservative_Tank_Volume_boom | ISOBUS | DDI539 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The actual volume inside the preservative tank. |
| In | Actual_Product_Pressure_boom | ISOBUS | DDI194 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Product Pressure is the measured pressure in the product flow system at the point of dispensing. |
| In | Actual_Revolutions_Per_Time_boom | ISOBUS | DDI390 | Cyclic | 10ms | FLOAT | RELEASED | 0.0.1 | Actual Revolutions specified as count per time |
| In | Actual_Seeding_Depth_boom | ISOBUS | DDI57 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Seeding Depth of Device Element below soil surface, value increases with depth |
| In | Actual_Sieve_Clearance_boom | ISOBUS | DDI243 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual separation distance between Sieve elements |
| In | Actual_Un_Loading_System_Status_boom | ISOBUS | DDI240 | Cyclic | 10ms | array | RELEASED | 0.0.1 | Actual status of the Unloading and/or Loading system. This DDE covers both Unloading and Loading of the device element w … |
| In | ActualBoomWorkingWidth | ISOBUS | DDI67 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Actual Working Width of boom/device |
| In | ActualCulturalPractice_boom | ISOBUS | DDI179 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This is used to define the current cultural practice which is performed by an individual device operation. |
| In | ActualPumpOutputPressure_boom | ISOBUS | DDI198 | Cyclic | 10ms | FLOAT | RELEASED | 0.0.1 | Actual Pump Output Pressure measured at the output of the solution pump. |
| In | ActualVolumeContent_tank_boom | ISOBUS | DDI72 | Cyclic | 10ms | INT_ARRAY | RELEASED | 0.0.1 | Actual Device Element Content specified as volume |
| In | ActualWorkState_boom | ISOBUS | DDI141 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Work State |
| In | AmbientTemperature_boom | ISOBUS | DDI192 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Ambient temperature measured by a machine. Unit is milli-Kelvin (mK). |
| In | ApplicationTotalMass_boom | ISOBUS | DDI81 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Application specified as mass in kilogram [kg] |
| In | ApplicationTotalMassingram_boom | ISOBUS | DDI352 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Application specified as mass in gram [g] |
| In | ApplicationTotalVolume_boom | ISOBUS | DDI351 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Application specified as volume in milliliter [ml] |
| In | ApplicationTotalVolume_boom | ISOBUS | DDI80 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Application specified as volume as liter [L] |
| In | Average_Applied_Preservative_Per_Yield_Mass_boom | ISOBUS | DDI538 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The average volume per mass for this task. |
| In | Average_Crop_Contamination_boom | ISOBUS | DDI408 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average amount of dirt or foreign in a harvested crop |
| In | Average_Crop_Moisture_boom | ISOBUS | DDI262 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Moisture of the harvested crop. This value is the average for a Task and may be reported as a total. |
| In | Average_Dry_Yield_Mass_Per_Area_boom | ISOBUS | DDI359 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Yield expressed as mass per unit area, corrected for the reference moisture percentage DDI 184. This value is th … |
| In | Average_Dry_Yield_Mass_Per_Time_boom | ISOBUS | DDI358 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Yield expressed as mass per unit time, corrected for the reference moisture percentage DDI 184. This value is th … |
| In | Average_Protein_Content_boom | ISOBUS | DDI407 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average protein content in a harvested crop |
| In | Average_Seed_Multiple_Percentage_boom | ISOBUS | DDI420 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Seed Multiple Percentage calculated from measured seed spacing using ISO 7256-1 "Multiples Index" algorithm. The … |
| In | Average_Seed_Singulation_Percentage_boom | ISOBUS | DDI416 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Seed Singulation Percentage calculated from measured seed spacing using ISO 7256-1 "Quality of Feed Index" algor … |
| In | Average_Seed_Skip_Percentage_boom | ISOBUS | DDI418 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Seed Skip Percentage calculated from measured seed spacing using ISO 7256-1 "Miss Index" algorithm. The value is … |
| In | Average_Seed_Spacing_Deviation_boom | ISOBUS | DDI422 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Seed Spacing Deviation from setpoint seed spacing. The value is the average for a Task. |
| In | Average_Yield_Mass_Per_Area_boom | ISOBUS | DDI263 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Yield expressed as mass per unit area, not corrected for the reference moisture percentage DDI 184. This value i … |
| In | Average_Yield_Mass_Per_Time_boom | ISOBUS | DDI261 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Yield expressed as mass per unit time, not corrected for the reference moisture percentage DDI 184. This value i … |
| In | AverageCoefficient_Seed_Spacing_Percentage_boom | ISOBUS | DDI424 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Coefficient of Variation of Seed Spacing Percentage calculated from measured seed spacing using ISO 7256-1 algor … |
| In | AveragePercentage_CropDryMatter_boom | ISOBUS | DDI315 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Average Percentage Crop Dry Matter expressed as parts per million. |
| In | bin_eti_boom | ISOBUS | DDI178 | Cyclic | 10ms | INT_ARRAY | RELEASED | 0.0.1 | This DDI is used to get bin indexes under Boom level. Default value when zero bins : 65535 |
| In | bin_eti_count_boom | ISOBUS | DDI178 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This DDI is used to enumerate and identify multiple device elements (DET) of the same type within one Device Description … |
| In | boom_workingwidth | ISOBUS | DDI70 | Cyclic | 10ms | FLOAT | RELEASED | 0.0.1 | Maximum Working Width of each section |
| In | boomGeometry_x | ISOBUS | DDI134 | Cyclic | 10ms | FLOAT | RELEASED | 0.0.1 | X direction offset of a DeviceElement relative to a Device. |
| In | boomGeometry_y | ISOBUS | DDI135 | Cyclic | 10ms | FLOAT | RELEASED | 0.0.1 | Y direction offset of a DeviceElement relative to a Device. |
| In | boomGeometry_z | ISOBUS | DDI136 | Cyclic | 10ms | FLOAT | RELEASED | 0.0.1 | Z direction offset of a DeviceElement relative to a Device. |
| In | channelcount | NEVONEX | - | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Number of Channels |
| In | Chopper_Engagement_Total_Time_boom | ISOBUS | DDI324 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated time while the chopping mechanism is engaged |
| In | closablesections | NEVONEX | - | Cyclic | 10ms | BOOLEAN | RELEASED | 0.0.1 | Section can be controllable ON/OFF. |
| In | Count_Per_Area_Crop_Loss_boom | ISOBUS | DDI94 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Crop yield loss as count per area |
| In | Count_Per_Area_Yield_boom | ISOBUS | DDI85 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Yield as count per area |
| In | Count_Per_Time_Crop_Loss_boom | ISOBUS | DDI97 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Crop yield loss as count per time |
| In | Count_Per_Time_Yield_boom | ISOBUS | DDI88 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Yield as count per time |
| In | Crop_Contamination_boom | ISOBUS | DDI100 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Dirt or foreign material in crop yield |
| In | Crop_Moisture_boom | ISOBUS | DDI99 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Moisture in crop yield |
| In | Crop_Temperature_boom | ISOBUS | DDI241 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Temperature of harvested crop |
| In | Dry_Mass_Per_Area_Yield_boom | ISOBUS | DDI181 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Dry Mass Per Area Yield. The definition of dry mass is the mass with a reference moisture specified by DDI 184. |
| In | Dry_Mass_Per_Time_Yield_boom | ISOBUS | DDI182 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Dry Mass Per Time Yield. The definition of dry mass is the mass with a reference moisture specified by DDI 184. |
| In | Effective_Total_Diesel_Exhst_Fluid_Cnsmptn_boom | ISOBUS | DDI318 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated total Diesel Exhaust Fluid consumption in working position. |
| In | Effective_Total_Fuel_Consumption_boom | ISOBUS | DDI316 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated total fuel consumption in working position. |
| In | Effective_Total_Loading_Time_boom | ISOBUS | DDI339 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total time needed in the current task to load a product such as crop. |
| In | Effective_Total_Unloading_Time_boom | ISOBUS | DDI340 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total time needed in the current task to unload a product crop. |
| In | EffectiveTotalTime_boom | ISOBUS | DDI119 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Time in working position |
| In | Gross_Weight_State_boom | ISOBUS | DDI233 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Gross Weight State, 2 bits defined as: |
| In | Hydraulic_Oil_Temperature_boom | ISOBUS | DDI258 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Temperature of fluid in the hydraulic system. |
| In | Ineffective_Total_Diesel_Exhst_Fluid_Cnsmptn_boom | ISOBUS | DDI319 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated total Diesel Exhaust Fluid consumption in non working position. |
| In | Ineffective_Total_Distance_boom | ISOBUS | DDI118 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Distance out of working position |
| In | Ineffective_Total_Fuel_Consumption_boom | ISOBUS | DDI317 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated total fuel consumption in non working position. |
| In | Ineffective_Total_Time_boom | ISOBUS | DDI120 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Time out of working position |
| In | Instantaneous_Area_Per_Time_Capacity_boom | ISOBUS | DDI151 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Area per time capacity |
| In | InstantaneousFuelConsumption_boom | ISOBUS | DDI149 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Fuel consumption per time |
| In | Last_Average_Bale_Compression_Plunger_Load_boom | ISOBUS | DDI220 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The average bale compression plunger load for the most recently produced bale expressed as percentage. |
| In | Last_Bale_Applied_Preservative_boom | ISOBUS | DDI221 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total preservative applied to the most recently produced bale. |
| In | Last_Bale_Average_Hydraulic_Pressure_boom | ISOBUS | DDI217 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The average actual value of the hydraulic pressure applied to the sides of the bale in the bale compression chamber. Thi … |
| In | Last_Bale_Average_Moisture_boom | ISOBUS | DDI212 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The average moisture in the most recently produced bale. |
| In | Last_Bale_Average_Strokes_per_Flake_boom | ISOBUS | DDI213 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The number of baler plunger compression strokes per flake that has entered the bale compression chamber. This value is t … |
| In | Last_Bale_Capacity_boom | ISOBUS | DDI528 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The capacity of the bale that leaves the machine. |
| In | Last_Bale_Flakes_per_Bale_boom | ISOBUS | DDI211 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The number of flakes in the most recently produced bale. |
| In | Last_Bale_Lifetime_Count_boom | ISOBUS | DDI519 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Lifetime Bale Count of the bale that leaves the machine. |
| In | Last_Bale_Mass_boom | ISOBUS | DDI223 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The mass of the bale that has most recently been produced. |
| In | Last_Bale_Number_of_Subbales_boom | ISOBUS | DDI482 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Number of smaller bales included in the latest produced bale. |
| In | Last_Bale_Tag_Number_boom | ISOBUS | DDI222 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Last Bale Tag Number as a decimal number in the range of 0 to 4294967295. Note that the value of this DDI has the li … |
| In | Last_loaded_Volume_boom | ISOBUS | DDI456 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Last loaded Volume value specified as volume |
| In | Last_unloaded_Volume_boom | ISOBUS | DDI457 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Last unloaded Volume value specified as volume |
| In | Lifetime_Applied_Preservative_boom | ISOBUS | DDI537 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total applied volume of preservative in the lifetime of the machine |
| In | Lifetime_Bale_Count_boom | ISOBUS | DDI214 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The number of bales produced by a machine over its entire lifetime. This DDE value can not be set through the process da … |
| In | Lifetime_Chopping_Engagement_Total_Time_boom | ISOBUS | DDI546 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Chopping Engagement Total Time of the device lifetime. |
| In | Lifetime_Ineffective_Total_Distance_boom | ISOBUS | DDI273 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Ineffective Total Distance of the device lifetime. |
| In | Lifetime_Ineffective_Total_Time_boom | ISOBUS | DDI275 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Ineffective Total Time of the device lifetime. |
| In | Lifetime_Loaded_Total_Count_boom | ISOBUS | DDI460 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Loaded Total Count of the device lifetime. |
| In | Lifetime_Loaded_Total_Mass_boom | ISOBUS | DDI430 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Mass of the device lifetime. |
| In | Lifetime_loaded_Total_Volume_boom | ISOBUS | DDI454 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire loaded Volume of the device lifetime. |
| In | Lifetime_Mesh_Bale_Total_Count_boom | ISOBUS | DDI525 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire total number of mesh product units for which Net binding method was used during operation, of a device lifetime |
| In | Lifetime_Precut_Total_Count_boom | ISOBUS | DDI285 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Precut Total Count of the device lifetime. |
| In | Lifetime_Threshing_Engagement_Total_Time_boom | ISOBUS | DDI282 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Threshing Engagement Total Time of the device lifetime. |
| In | Lifetime_Twine_Bale_Total_Count_boom | ISOBUS | DDI524 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire total number of twine bound product units for which Twine binding method was used during operation, of a device l … |
| In | Lifetime_Uncut_Total_Count_boom | ISOBUS | DDI286 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Uncut Total Count of the device lifetime. |
| In | Lifetime_Unloaded_Total_Count_boom | ISOBUS | DDI461 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Unloaded Total Count of the device lifetime. |
| In | Lifetime_Unloaded_Total_Mass_boom | ISOBUS | DDI431 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Unloaded Total Mass of the device lifetime. |
| In | Lifetime_Unloaded_Total_Volume_boom | ISOBUS | DDI455 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire unloaded Volume of the device lifetime. |
| In | Lifetime_Yield_Total_Count_boom | ISOBUS | DDI270 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Count of the device lifetime. |
| In | Lifetime_Yield_Total_Dry_Mass_boom | ISOBUS | DDI279 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Dry Mass of the device lifetime. |
| In | Lifetime_Yield_Total_Lint_Cotton_Mass_boom | ISOBUS | DDI281 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Lint Cotton Mass of the device lifetime. |
| In | Lifetime_Yield_Total_Mass_boom | ISOBUS | DDI269 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Mass of the device lifetime. |
| In | Lifetime_Yield_Total_Seed_Cotton_Mass_boom | ISOBUS | DDI280 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Seed Cotton Mass of the device lifetime. |
| In | Lifetime_Yield_Total_Volume_boom | ISOBUS | DDI268 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Yield Total Volume of the device lifetime. |
| In | LifetimeApplicationTotalCount_boom | ISOBUS | DDI267 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Application Total Count of the device lifetime. |
| In | LifetimeApplicationTotalVolume_boom | ISOBUS | DDI325 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Application Total Volume of the device lifetime. |
| In | LifetimeEffectiveTotalDistance_boom | ISOBUS | DDI272 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Total Distance of the device lifetime in working position. |
| In | LifetimeEffectiveTotalTime_boom | ISOBUS | DDI274 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Effective Total Time of the device lifetime. |
| In | LifetimeTotalArea_boom | ISOBUS | DDI271 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Entire Total Area of the device lifetime. |
| In | Lint_Cotton_Mass_Per_Area_Yield_boom | ISOBUS | DDI186 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Lint cotton yield as mass per area. |
| In | Lint_Cotton_Mass_Per_Time_Yield_boom | ISOBUS | DDI188 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Lint cotton yield as mass per time. |
| In | Lint_Turnout_Percentage__boom | ISOBUS | DDI191 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Percent of lint in the seed cotton. |
| In | Loaded_Total_Count_boom | ISOBUS | DDI458 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Loads specified as count |
| In | Loaded_Total_Mass_boom | ISOBUS | DDI428 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Loads specified as mass, not corrected for the reference moisture percentage DDI 184. |
| In | Loaded_Total_Volume_boom | ISOBUS | DDI452 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Loaded Volume specified as volume |
| In | Log_Count_boom | ISOBUS | DDI147 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Log Counter, may be used to control data log record generation on a Task Controller |
| In | Mass_Per_Area_Crop_Loss_boom | ISOBUS | DDI93 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Crop yield loss as mass per area |
| In | Mass_Per_Area_Yield_boom | ISOBUS | DDI84 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Yield as mass per area, not corrected for the reference moisture percentage DDI 184. |
| In | Mass_Per_Time_Crop_Loss_boom | ISOBUS | DDI96 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Crop yield loss as mass per time |
| In | Mass_Per_Time_Yield_boom | ISOBUS | DDI87 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Yield as mass per time, not corrected for the reference moisture percentage DDI 184. |
| In | MaximumVolumeContent_tank_boom | ISOBUS | DDI73 | Cyclic | 10ms | INT_ARRAY | RELEASED | 0.0.1 | Maximum Device Element Content specified as volume |
| In | Mesh_Bale_Total_Count_boom | ISOBUS | DDI523 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total number of mesh product units for which Net binding method was used during operation. |
| In | Mntrd_Physical_Setpt_Time_Latency_tank_boom | ISOBUS | DDI142 | Cyclic | 10ms | INT_ARRAY | RELEASED | 0.0.1 | The Setpoint Value Latency Time is the time lapse between the moment of receival of a setpoint value command by the work … |
| In | MntrdSetpnt_Apld_Prsrvtv_PerYieldMass_boom | ISOBUS | DDI532 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The desired volume of preservative per harvested yield mass |
| In | MntrdSetpoint_Chaffer_Clearance_boom | ISOBUS | DDI246 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint separation distance between Chaffer elements. |
| In | MntrdSetpoint_Concave_Clearance_boom | ISOBUS | DDI250 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint separation distance between Concave elements. |
| In | MntrdSetpoint_Sieve_Clearance_boom | ISOBUS | DDI242 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint separation distance between Sieve elements |
| In | MntrdSetpoint_Sprtn_Fan_Rotational_Speed_boom | ISOBUS | DDI254 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint rotational speed of the fan used for separating product material from non product material. |
| In | MntrdSetPt_Bale_Compression_Plunger_Load_boom | ISOBUS | DDI218 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The setpoint bale compression plunger load expressed as percentage |
| In | MntrdSetPt_Bale_Compression_Plunger_Load_N_boom | ISOBUS | DDI547 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The setpoint bale compression plunger load expressed as Newton. |
| In | MntrdSetPt_Max_Allowed_Seed_Spacing_Deviation_boom | ISOBUS | DDI425 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Maximum Allowed Seed Spacing Deviation |
| In | MntrdSetPt_Tramline_Condensed_Work_State_boom | ISOBUS | DDI517 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Setpoint Tramline Condensed Work State DDIs are the control command counterparts to the Actual Tramline Condensed Wo … |
| In | MonitoredSetpnt_SeedingDepth_boom | ISOBUS | DDI56 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Seeding Depth of Device Element below soil surface, value increases with depth Setpoint Working Height of Devic … |
| In | MonitoredSetpnt_TillageDepth_boom | ISOBUS | DDI51 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Tillage Depth of Device Element below soil surface, value increases with depth. In case of a negative value the … |
| In | MonitoredSetpnt_WorkingHeight_boom | ISOBUS | DDI61 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Working Height of Device Element above crop or soil |
| In | MonitoredSetpnt_WorkingLength_boom | ISOBUS | DDI225 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Working Length of Device Element. |
| In | MonitoredSetpnt_WorkingWidth_boom | ISOBUS | DDI66 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Working Width of Device Element |
| In | MonitoredSetpoint_Bale_Height_boom | ISOBUS | DDI106 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Bale Height is only applicable to square baler |
| In | MonitoredSetpoint_Bale_Hydraulic_Pressure_boom | ISOBUS | DDI475 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The setpoint value of the hydraulic pressure applied to the sides of the bale in the bale compression chamber. |
| In | MonitoredSetpoint_Bale_Size_boom | ISOBUS | DDI111 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Bale Size as length for a square baler or diameter for a round baler |
| In | MonitoredSetpoint_Bale_Width_boom | ISOBUS | DDI101 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Bale Width for square baler or round baler |
| In | MonitoredSetpoint_Cutting_drum_speed_boom | ISOBUS | DDI330 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The setpoint speed of the cutting drum of a chopper |
| In | MonitoredSetpoint_Downforce_Force_boom | ISOBUS | DDI426 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Monitored Setpoint Downforce as Force |
| In | MonitoredSetpoint_Downforce_Pressure_boom | ISOBUS | DDI365 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Monitored Setpoint downforce pressure for an operation |
| In | MonitoredSetpoint_Electrical_Current_boom | ISOBUS | DDI557 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint electrical Current of a Device Element |
| In | MonitoredSetpoint_Electrical_Power_boom | ISOBUS | DDI568 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Electrical Power of Device Element |
| In | MonitoredSetpoint_Flake_Size_boom | ISOBUS | DDI478 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint size of the flake to be produced by the chamber. |
| In | MonitoredSetpoint_Frequency_boom | ISOBUS | DDI583 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Frequency of Device Element specified as Hz |
| In | MonitoredSetpoint_Grain_Kernel_Cracker_Gap_boom | ISOBUS | DDI341 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The setpoint gap (distance) of the grain kernel cracker drums in a chopper. |
| In | MonitoredSetpoint_Header_Speed_boom | ISOBUS | DDI326 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | The setpoint rotational speed of the header attachment of a chopper, mower or combine |
| In | MonitoredSetpoint_Length_of_Cut_boom | ISOBUS | DDI472 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint length of cut for harvested material, e.g. Forage Harvester or Tree Harvester. |
| In | MonitoredSetpoint_Net_Weight_boom | ISOBUS | DDI231 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Net Weight value. |
| In | MonitoredSetpoint_Number_of_Subbales_boom | ISOBUS | DDI481 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Number of smaller bales that shall be included in one bigger bale. |
| In | MonitoredSetpoint_Setpoint_Swathing_Width_boom | ISOBUS | DDI345 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This is the setpoint swathing width of the swath created by a raker. |
| In | MonitoredSetpoint_Temperature_boom | ISOBUS | DDI578 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Temperature of Device Element specified as milli Kelvin |
| In | MonitoredSetpoint_Tillage_Disc_Gang_Angle_boom | ISOBUS | DDI529 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Tillage Gang Angle is the pivot angle of the gangs for the device element |
| In | MonitoredSetpoint_Voltage_boom | ISOBUS | DDI562 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Voltage of a Device Element |
| In | MonitoredSetpointProductPressure_boom | ISOBUS | DDI193 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Product Pressure to adjust the pressure of the product flow system at the point of dispensing. |
| In | MonitoredSetpointPumpOutputPressure_boom | ISOBUS | DDI197 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Pump Output Pressure to adjust the pressure at the output of the solution pump. |
| In | MonitoredSetpointTankAgitationPressure_boom | ISOBUS | DDI201 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Tank Agitation Pressure to adjust the pressure for a stir system in a tank. |
| In | MonitoredSetpointVolumeContent_boom | ISOBUS | DDI71 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Setpoint Device Element Content specified as volume |
| In | MonitoredSetpointWorkState_boom | ISOBUS | DDI289 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Control command counterparts to the Work State DDI (141). |
| In | Net_Weight_State_boom | ISOBUS | DDI230 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Net Weight State, 2 bits defined as: |
| In | NozzleDriftReduction_boom | ISOBUS | DDI349 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Nozzle Drift Reduction classification value of the spraying equipment as percentage |
| In | Operating_Hours_Since_Last_Sharpening_boom | ISOBUS | DDI334 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This value describes the working hours since the last sharpening of the cutting device. |
| In | Percentage_Crop_Loss_boom | ISOBUS | DDI98 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Crop yield loss |
| In | PhysicalActualValueTimeLatency_boom | ISOBUS | DDI143 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Actual Value Latency Time |
| In | PhysicalActualValueTimeLatency_tank_boom | ISOBUS | DDI143 | Cyclic | 10ms | INT_ARRAY | RELEASED | 0.0.1 | Actual Value Latency Time |
| In | Precut_Total_Count_boom | ISOBUS | DDI283 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total number of pre-cutted product units produced by a device during an operation. |
| In | Product_Density_Mass_PerCount_boom | ISOBUS | DDI122 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Product Density as mass per count |
| In | Product_Density_Volume_Per_Count_boom | ISOBUS | DDI123 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Product Density as volume per count |
| In | ProductDensity_boom | ISOBUS | DDI121 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Product Density as mass per volume |
| In | Reference_Moisture_For_Dry_Mass_boom | ISOBUS | DDI184 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Moisture percentage used for the dry mass DDIs 181, 182 and 183. |
| In | Relative_Yield_Potential_boom | ISOBUS | DDI311 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Relative yield potential provided by a FMIS or a sensor or entered by the operator for a certain task expressed as perce … |
| In | SC_Turn_Off_Time_boom | ISOBUS | DDI206 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Section Control Turn Off Time defines the overall time lapse between the moment the TC sends a turn off section comm … |
| In | SC_Turn_On_Time_boom | ISOBUS | DDI205 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The Section Control Turn On Time defines the overall time lapse between the moment the TC sends a turn on section comman … |
| In | SectionControlState_boom | ISOBUS | DDI160 | Cyclic | 10ms | enum | RELEASED | 0.0.1 | Actual state of section control |
| In | sectioncount | NEVONEX | - | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Number of sections |
| In | Seed_Cotton_Mass_Per_Area_Yield_boom | ISOBUS | DDI185 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Seed cotton yield as mass per area, not corrected for a possibly included lint percantage. |
| In | Seed_Cotton_Mass_Per_Time_Yield_boom | ISOBUS | DDI187 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Seed cotton yield as mass per time, not corrected for a possibly included lint percantage. |
| In | Setpoint_Revolutions | ISOBUS | DDI389 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Setpoint Revolutions specified as count per time |
| In | Thresher_Engagement_Total_Time_boom | ISOBUS | DDI236 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated time while the threshing mechanism is engaged |
| In | Total_Applied_Preservative_boom | ISOBUS | DDI536 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total volume of applied preservative in this task. |
| In | Total_Bale_Length_boom | ISOBUS | DDI362 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Gives the total baled meters during a task. This is calculated as the sum of the lengths of all knotted bales (square ba … |
| In | Total_Diesel_Exhaust_Fluid_Consumption_boom | ISOBUS | DDI409 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Diesel Exhaust Fluid Consumption as a Task Total. |
| In | Total_Fuel_Consumption_boom | ISOBUS | DDI148 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Fuel Consumption as Counter |
| In | Total_Revolutions_in_Complete_Revolutions_boom | ISOBUS | DDI388 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Revolutions specified as completed integer revolutions |
| In | Total_Revolutions_in_Fractional_Revolutions_boom | ISOBUS | DDI387 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Accumulated Revolutions specified with fractional revolutions |
| In | TotalApplicationofAmmonium_boom | ISOBUS | DDI354 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated application of ammonium [NH4] specified as gram [g] |
| In | TotalApplicationofDryMatter_boom | ISOBUS | DDI357 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated application of dry matter in kilogram [kg]. Dry matter measured at zero percent of moisture |
| In | TotalApplicationofNitrogen_boom | ISOBUS | DDI353 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated application of nitrogen [N2] specified as gram [g] |
| In | TotalApplicationofPhosphor_boom | ISOBUS | DDI355 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated application of phosphor (P2O5) specified as gram [g] |
| In | TotalApplicationofPotassium_boom | ISOBUS | DDI356 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated application of potassium (K2) specified as gram [g] |
| In | TotalAreaPlanted_boom | ISOBUS | DDI116 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Area |
| In | TotalAreaPlantedhectare_boom | ISOBUS | DDI116 | Cyclic | 10ms | DOUBLE | RELEASED | 0.0.1 | Accumulated Area in Hectare |
| In | TotalDistance_boom | ISOBUS | DDI117 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Distance in working position |
| In | Tramline_Control_State_boom | ISOBUS | DDI515 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Specifies the actual state of Tramline Control |
| In | Tramline_GNSS_Quality_boom | ISOBUS | DDI514 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | GNSS Quality Identifier to inform the implement about the used Position Status |
| In | Tramline_Track_Number_boom | ISOBUS | DDI509 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This DDI defines a unique number of the Guidance Track the Implement is currently located on |
| In | Tramline_Track_to_the_Left_boom | ISOBUS | DDI511 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This DDI defines a unique number of the Guidance Track to left hand side in direction of Implement orientation |
| In | Tramline_Track_to_the_Right_boom | ISOBUS | DDI510 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | This DDI defines a unique number of the Guidance Track to right hand side in direction of Implement orientation |
| In | Twine_Bale_Total_Count_boom | ISOBUS | DDI522 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total number of twine bound product units for which Twine binding method was used during operation. |
| In | Uncut_Total_Count_boom | ISOBUS | DDI284 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | The total number of un-cutted product units produced by a device during an operation. |
| In | Unloaded_Total_Count_boom | ISOBUS | DDI459 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Unloaded specified as count |
| In | Unloaded_Total_Mass_boom | ISOBUS | DDI429 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Unloads specified as mass, not corrected for the reference moisture percentage DDI 184. |
| In | Unloaded_Total_Volume_boom | ISOBUS | DDI453 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Unloaded Volume specified as volume |
| In | VariableSections | NEVONEX | - | Cyclic | 10ms | INT | RELEASED | 0.0.1 | whether Variable rate control is possible at sections level. This interface not supported. This property marked as false … |
| In | Volume_Per_Area_Crop_Loss_boom | ISOBUS | DDI92 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Crop yield loss as volume per area |
| In | Volume_Per_Area_Yield_boom | ISOBUS | DDI83 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Yield as volume per area |
| In | Volume_Per_Time_Crop_Loss_boom | ISOBUS | DDI95 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Crop yield loss as volume per time |
| In | Volume_Per_Time_Yield_boom | ISOBUS | DDI86 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Yield as volume per time |
| In | Yield_Hold_Status_boom | ISOBUS | DDI239 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Status indicator for the yield measurement system. When enabled/on, the measurements from the yield measurement system a … |
| In | Yield_Lag_Ignore_Time_boom | ISOBUS | DDI259 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Amount of time to ignore yield data, starting at the transition from the in-work to the out-of-work state. During this t … |
| In | Yield_Lead_Ignore_Time_boom | ISOBUS | DDI260 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Amount of time to ignore yield data, starting at the transition from the out-of-work to the in-work state. During this t … |
| In | Yield_Total_Count_boom | ISOBUS | DDI91 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Yield specified as count |
| In | Yield_Total_Dry_Mass_boom | ISOBUS | DDI183 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Yield specified as dry mass. The definition of dry mass is the mass with a reference moisture specified by D … |
| In | Yield_Total_Lint_Cotton_Mass_boom | ISOBUS | DDI190 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated yield specified as lint cotton mass. |
| In | Yield_Total_Mass_boom | ISOBUS | DDI90 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Yield specified as mass, not corrected for the reference moisture percentage DDI 184. |
| In | Yield_Total_Seed_Cotton_Mass_boom | ISOBUS | DDI189 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated yield specified as seed cotton mass, not corrected for a possibly included lint percantage. |
| In | Yield_Total_Volume_boom | ISOBUS | DDI89 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Accumulated Yield specified as volume |

### Connector (Machine ID: 609)

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | connectorgeometry_x | ISOBUS | DDI134 | Cyclic | 10ms | FLOAT | RELEASED | 0.0.1 | X direction offset of a DeviceElement relative to a Device. |
| In | connectorgeometry_y | ISOBUS | DDI135 | Cyclic | 10ms | FLOAT | RELEASED | 0.0.1 | Y direction offset of a DeviceElement relative to a Device. |
| In | connectorgeometry_z | ISOBUS | DDI136 | Cyclic | 10ms | FLOAT | RELEASED | 0.0.1 | Z direction offset of a DeviceElement relative to a Device. |
| In | connectorType | ISOBUS | DDI157 | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Specification of the type of coupler. The value definitions are: -1 = Not available 0 = unknown (default), 1 = ISO 6489- … |

## Signal Fields

### Actual_Un_Loading_System_Status

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| unloading | ActualWorkState | - | - |
| loading | ActualWorkState | - | - |

### DeviceInfo

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| ID | STRING | - | - |
| Designator | STRING | - | - |
| SoftwareVersion | STRING | - | - |
| ClientName | STRING | - | - |
| SerialNumber | STRING | - | - |
| StructureLabel | STRING | - | - |
| LocalizationLabel | STRING | - | - |

### Actual_Un_Loading_System_Status_boom

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| unloading | ActualWorkState | - | - |
| loading | ActualWorkState | - | - |
