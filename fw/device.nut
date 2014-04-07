// Internet enabled accelerometer
 server.log("Hello");
    
 
/**************************** Hardware *******************************************/
 /* Pin Assignments according to silkscreen
 * Pin 1 = Input: wakeup interrupt from accelerometer
 * Pin 2 = PWM Red
 * Pin 5 = PWM Blue
 * Pin 7 = PWM Green
 * Pin 8 = I2C SCL
 * Pin 9 = I2C SDA
*/
 
// PWM frequency in Hz
local pwm_f = 500.0;
hardware.pin2.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin5.configure(PWM_OUT, 1.0/pwm_f, 1.0);
hardware.pin7.configure(PWM_OUT, 1.0/pwm_f, 1.0);

hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
i2c <- hardware.i2c89 // now can use i2c.read()

/**************************** LED *******************************************/
// Variable to represent LED state
local goalLED = [0xFF, 0xFF, 0xFF];
local currentLED = [0, 0, 0];
local ledSteps = 20 // steps in ramp at 100ms
local currentLedStep = 0 
local inLEDRamp = false;

class LEDColor extends InputPort
{
    type = "array"
    name = "goalLED"
    redPin = null
    grnPin = null
    bluPin = null


    constructor(name, redPin, grnPin, bluPin) {
        this.redPin = redPin
        this.grnPin = grnPin
        this.bluPin = bluPin
        this.off();
    }
 
    function set(value) {
        goalLED[0] = value.r;
        goalLED[1] = value.g;
        goalLED[2] = value.b;
        if ("name" in value) {
            server.log(format("%s sent color: %02X, %02X, %02X", value.name, 
            goalLED[0], goalLED[1], goalLED[2]));      
        } else {
            server.log(format("No name: color %02X, %02X, %02X", 
            goalLED[0], goalLED[1], goalLED[2]));      
        }
        ledHugRamp();
        hardware.sampler.start();
        
    }
    function update() {
        local div =  (1.0/255.0);
        this.redPin.write( currentLED[0] * div);
        this.grnPin.write( currentLED[1] * div);
        this.bluPin.write( currentLED[2] * div);
    }        
    function off() {
        this.redPin.write(0);
        this.grnPin.write(0);
        this.bluPin.write(0);
    }
}
local rgbLed = LEDColor("RGBLed", hardware.pin2, hardware.pin5, hardware.pin7);

function ledHugRamp() {
    local difference = [0, 0, 0];
    local totalDifference = 0;
    local i;
    for (i = 0; i < 3; i++) {
        difference[i] = goalLED[i] - currentLED[i];   
        if (0 < difference[i] && difference[i] < ledSteps) {
            difference[i] = ledSteps; // will be 1 after divide
            
        } else if (0 > difference[i] && -difference[i] < ledSteps) {
            difference[i] = -ledSteps; // will be -1
        }
        currentLED[i] += (difference[i] / ledSteps);
        totalDifference += difference[i];
    }
    if (-3 < totalDifference && totalDifference < 3) {
        local goal = 0;
        for (i = 0; i < 3; i++) {
            goal += goalLED[i];
            currentLED[i] = goalLED[i]; 
            goalLED[i] = 0;
        }
        if (goal == 0) {
            // finished
            inLEDRamp = false;
            rgbLed.off();
            server.log(format("OFF"));              
        } else {
            rgbLed.update();
            imp.wakeup(5.0, ledHugRamp);        // it will start ramping down
        }
    } else {   
        rgbLed.update();
        imp.wakeup(0.05, ledHugRamp);
    }
}

function setHugColor (rgb)
{
    if (inLEDRamp) {
        
    
    } else {
        goalLED[0] = rgb[0];
        goalLED[1] = rgb[1];
        goalLED[2] = rgb[2];
        ledHugRamp();
        inLEDRamp = true;
        hardware.sampler.start();
    }
}

/************************ Accelerometer ***************************************/
// Many thanks to https://gist.github.com/duppypro/7225636 
// I mooched much of that code
const MMA8452Q_ADDR = 0x1D // A '<< 1' is needed.  I add the '<< 1' in the helper functions.
const STATUS        = 0x00
const OUT_X_MSB        = 0x01
const WHO_AM_I         = 0x0D
const I_AM_MMA8452Q    = 0x2A // read addr WHO_AM_I, expect I_AM_MMA8452Q
const INT_SOURCE       = 0x0C
    const SRC_ASLP_BIT        = 0x80
    const SRC_TRANSIENT_BIT   = 0x20
    const SRC_ORIENTATION_BIT = 0x10
    const SRC_PULSE_BIT       = 0x08
    const SRC_FF_MT_BIT       = 0x04
    const SRC_DRDY_BIT        = 0x01
    
const TRANSIENT_CFG = 0x1D
const TRANSIENT_SRC = 0x1E
const TRANSIENT_THRESHOLD = 0x1F
const TRANSIENT_COUNT = 0x20

const PULSE_CFG = 0x21
const PULSE_SRC = 0x22
const PULSE_THSX = 0x23
const PULSE_THSY = 0x24
const PULSE_THSZ = 0x25
const PULSE_TMLT = 0x26
const PULSE_LTCY = 0x27
const PULSE_WIND = 0x28


const CTRL_REG1         = 0x2A
    const GOAL_DATA_RATE = 0x20 // 100 Hz
    const CLEAR_DATA_RATE =0xC7
    const LNOISE_BIT       = 0x4
    const F_READ_BIT       = 0x2
    const ACTIVE_BIT       = 0x1    

const CTRL_REG2        = 0x2B
    const ST_BIT           = 0x7
    const RST_BIT          = 0x6
    const SLEEP_OVERSAMPLE_CLEAR = 0xE7 
    const SLEEP_OVERSAMPLE_SET = 0x18 // 11 = low power
    const AUTOSLEEP_BIT         = 0x4
    const NORMAL_OVERSAMPLE_CLEAR = 0xFC 
    const NORMAL_OVERSAMPLE_SET = 0x03 // 11 = low power

const CTRL_REG3        = 0x2C
    const WAKE_TRANSIENT_BIT     = 0x40
    const WAKE_ORIENTATION_BIT   = 0x20
    const WAKE_PULSE_BIT         = 0x10
    const WAKE_FREEFALL_BIT      = 0x08
    const IPOL_BIT               = 0x02
    
const CTRL_REG4        = 0x2D
    const INT_EN_ASLP_BIT        = 0x80
    const INT_EN_TRANSIENT_BIT   = 0x20
    const INT_EN_ORIENTATION_BIT = 0x10
    const INT_EN_PULSE_BIT       = 0x08
    const INT_EN_FREEFALL_MT_BIT = 0x04
    const INT_EN_DRDY_BIT        = 0x01

const CTRL_REG5        = 0x2E


// Writes a single byte (dataToWrite) into addressToWrite.  Returns error code from i2c.write
// Continue retry until success.  Caller does not need to check error code
function writeReg(addressToWrite, dataToWrite) {
    local err = null
    while (err == null) {
        err = i2c.write(MMA8452Q_ADDR << 1, format("%c%c", addressToWrite, dataToWrite))
        // server.log(format("i2c.write addr=0x%02x data=0x%02x", addressToWrite, dataToWrite))
        if (err == null) {
            server.error("i2c.write of value " + format("0x%02x", dataToWrite) + " to " + format("0x%02x", addressToWrite) + " failed.")
            imp.sleep(i2cRetryPeriod)
            server.error("retry i2c.write")
        }
    }
    return err
    
}
 
// Read numBytes sequentially, starting at addressToRead
// Continue retry until success.  Caller does not need to check error code
function readSequentialRegs(addressToRead, numBytes) {
    local data = null
    
    while (data == null) {
        data = i2c.read(MMA8452Q_ADDR << 1, format("%c", addressToRead), numBytes)
        if (data == null) {
            server.error("i2c.read from " + format("0x%02x", addressToRead) + " of " + numBytes + " byte" + ((numBytes > 1) ? "s" : "") + " failed.")
            imp.sleep(i2cRetryPeriod)
            server.error("retry i2c.read")
        }
    }
    return data
}
 
function readReg(addressToRead) {
    return readSequentialRegs(addressToRead, 1)[0]
}  
// Reset the MMA8452Q
function MMA8452QReset() {
    local reg
    
    do {
        reg = readReg(WHO_AM_I)  // Read WHO_AM_I register
        if (reg == I_AM_MMA8452Q) {
            server.log("Found MMA8452Q.  Sending RST command...")
            break
        } else {
            server.error("Could not connect to MMA8452Q: WHO_AM_I reg == " + format("0x%02x", reg))
            imp.sleep(i2cRetryPeriod)
        }
    } while (true)

    // send reset command
    writeReg(CTRL_REG2, readReg(CTRL_REG2) | RST_BIT)
 
    do {
        reg = readReg(WHO_AM_I)  // Read WHO_AM_I register
        if (reg == I_AM_MMA8452Q) {
            server.log("accel ok")
            break
        } else {
            server.error("Could not connect to MMA8452Q: WHO_AM_I reg == " + format("0x%02x", reg))
            imp.sleep(i2cRetryPeriod)
        }
    } while (true)
    
    MMA8452QSetActive(false);
    writeReg(CTRL_REG1, 0x1A); // 100 Hz ODR + fast read + low noise
    
    // Set up accel for transient detection, see 
    // http://cache.freescale.com/files/sensors/doc/app_note/AN4071.pdf
    writeReg(TRANSIENT_CFG, 0x1E); // Enable X Y Z Axes and enable the latch
    writeReg(TRANSIENT_THRESHOLD, 0x02); // experimentally derived threshold
    writeReg(TRANSIENT_COUNT, 0x05); // 50ms
    reg = readReg(TRANSIENT_SRC) // this clears the register
    
    // Set up accel for single tap pulse detection, see 
    // http://cache.freescale.com/files/sensors/doc/app_note/AN4072.pdf
    writeReg(PULSE_CFG, 0x55); // Enable X Y Z Axes and enable the latch
    const tapThreshold = 10;  // experimentally derived threshold
    writeReg(PULSE_THSX, tapThreshold); 
    writeReg(PULSE_THSY, tapThreshold); 
    writeReg(PULSE_THSZ, tapThreshold); 
    writeReg(PULSE_TMLT, 0x03); // 30ms at 100Hz ODR
    writeReg(PULSE_LTCY, 100);  // 100ms at 100Hz ODR
    reg = readReg(PULSE_SRC) // this clears the register

    writeReg(CTRL_REG4, INT_EN_TRANSIENT_BIT | INT_EN_PULSE_BIT); 
    writeReg(CTRL_REG5, INT_EN_TRANSIENT_BIT | INT_EN_PULSE_BIT);  

    writeReg(CTRL_REG3, WAKE_TRANSIENT_BIT | WAKE_PULSE_BIT | IPOL_BIT);  // move to int1
    
    MMA8452QSetActive(true);
}
function MMA8452QSetActive(mode) {
    // Sets the MMA8452Q active mode. 
    // 0 == STANDBY for changing registers
    // 1 == ACTIVE for outputting data
    if (mode) {
        writeReg(CTRL_REG1, readReg(CTRL_REG1) | ACTIVE_BIT)
    } else {
        writeReg(CTRL_REG1, readReg(CTRL_REG1) & ~ACTIVE_BIT)
    }
}
function readAccelData() {
    local rawData = null // x/y/z accel register data stored here, 3 bytes
    local signedData = [0,0,0];
    rawData = readSequentialRegs(OUT_X_MSB, 3)  // Read the three raw data registers into data array
    foreach (i, val in rawData) {
        val = (val < 128 ? val : val - 256);
        // now val is -128 to 128 and 2G
        val = (val < 0 ? -val : val);
        val = val * 2;
        // I want absolute value, 0 to 256 and 1G
        signedData[i] = (val > 256 ? 255 : val);
        
    }
    return signedData;
}

function MMA8452QInterruptHandler() {
    local reg
 
    if (hardware.pin1.read() == 1) { // only react to low to high edge
        reg = readReg(INT_SOURCE)
        if (reg & SRC_TRANSIENT_BIT) {
            reg = readReg(TRANSIENT_SRC) // this clears SRC_TRANSIENT_BIT
            server.log(format("Transient src 0x%02x", reg))
            agent.send("motionDetected", "soft gentle motion.");
            accelReadSetColor();
        }

        
        if (reg & SRC_PULSE_BIT) {
            reg = readReg(PULSE_SRC) // this clears SRC_PULSE_BIT
            server.log(format("Pulse src 0x%02x", reg))
            agent.send("motionDetected", "hard rapping.");
            accelReadSetColor();
        }

    } else {
//        server.log("INT LOW")
    }
} // MMA8452QInterruptHandler
/************************ General ***************************************/

function accelReadSetColor()
{
    local data = readAccelData();
//    server.log("accels " + data[0] + " " + data[1] + " " + data[2])
    setHugColor(data);
} 


//imp.setpowersave(true);

agent.on("hug", setHugColor);
MMA8452QReset();
// Configure pin1 for wakeup.  Connect MMA8452Q INT1 pin to imp pin1.
hardware.pin1.configure(DIGITAL_IN_WAKEUP, MMA8452QInterruptHandler);
