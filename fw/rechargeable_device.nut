/************************ Fuel Gauge battery monitoring ************************/
// MAX17043 LiPo fuel gauge to determine the state of charge (SOC) since simply 
// checking the voltage on a LiPo is unlikely to account for a good reading
// (also, my A/D pin is otherwise occupied)

// Holding both SDA and SCL logic-low forces the MAX17043/MAX17044 into Sleep mode.
// Alternatively, set the SLEEP bit in the CONFIG register to logic 1 through I2C
// To exit Sleep mode, write SLEEP to logic 0

const FUEL_GAGUE_ADDR = 0x6C  // 0x6C write, 0x6D read
const VCELL_REG       = 0x02  // Reports 12-bit A/D measurement of battery voltage. (R)
const SOC_REG         = 0x04  // Reports 16-bit SOC result calculated by ModelGauge algorithm. (R)
const MODE_REG        = 0x06  // Sends special commands to the IC. (W)
const VERSION_REG     = 0x08  // Returns IC version. (R)
const VERSION_EXPECTED = 0x0003
const CONFIG_REG      = 0x0C  // Battery compensation. Adjusts IC performance based on application conditions.   (R/W)
const COMMAND_REG     = 0xFE  // Sends special commands to the IC. (W)

function FuelGaugeReadVersion()
{
	local numBytes = 2;
	local data;
    data = i2c.read(FUEL_GAGUE_ADDR, format("%c", VERSION_REG), numBytes);
	if (data) {
        local tmp = (data[0] << 8) + data[1];
        if (tmp == VERSION_EXPECTED) {
		    server.log("Fuel gauge found.");
	    } else {
    		server.log("Fuel gauge version " + format("0x%02x 0x%02X", data[0], data[1]));
	    }
		return 
	} else {
		server.log("Nothing read from fuel gauge.");
	}
}

function FuelGaugeReadSoC()
{
    
	local numBytes = 2;
	local data;
    data = i2c.read(FUEL_GAGUE_ADDR, format("%c", SOC_REG), numBytes);
	if (data) {
        local tmp = data[0];
        server.log("Fuel gauge read " + tmp);
		return tmp;
	} else {
	    server.log("ERROR: cannot read fuel gauge!")
	}
}

function FuelGaugeSleep(state) 
{
    // add commands to put the fg in and out of sleep mode
}
function FuelGaugeResetFromBoot()
{
	FuelGaugeReadVersion();
	FuelGaugeReadSoC();
}

