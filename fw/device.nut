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
const accelerometer = 0x1D;
const out_x = 0x01;
const xyz_data = 0x0E;
const who_am_i = 0x0D;
const control_reg = 0x2A;


/**************************** LED *******************************************/
// Variable to represent LED state
local goalLED = [0xFF, 0xFF, 0xFF];
local currentLED = [0, 0, 0];
local ledSteps = 20 // steps in ramp at 100ms
local currentLedStep = 0 

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

function setLed(state)
{
    if (state) {
        goalLED[0] = 0;
        goalLED[1] = 255;
        goalLED[2] = 255;
    } else {
        goalLED[0] = 255;
        goalLED[1] = 0;
        goalLED[2] = 255;
    }
        
    ledHugRamp(); 
    hardware.sampler.start();

}
function setHugColor (rgb)
{
        goalLED[0] = rgb[0];
        goalLED[1] = rgb[1];
        goalLED[2] = rgb[2];
        ledHugRamp();
        hardware.sampler.start();
}

/************************ Accelerometer ***************************************/
// Many thanks to https://gist.github.com/duppypro/7225636 !!
const MMA8452Q_ADDR = 0x1D // A '<< 1' is needed.  I add the '<< 1' in the helper functions.
const OUT_X_MSB        = 0x01
const WHO_AM_I         = 0x0D
const I_AM_MMA8452Q    = 0x2A // read addr WHO_AM_I, expect I_AM_MMA8452Q
const CTRL_REG2        = 0x2B
    const ST_BIT           = 0x80
    const RST_BIT          = 0x40

const CTRL_REG1        = 0x2A
    const GOAL_DATA_RATE = 0x20 // 100 Hz
    const CLEAR_DATA_RATE =0xC7
    const LNOISE_BIT       = 0x4
    const F_READ_BIT       = 0x2
    const ACTIVE_BIT       = 0x1    
    
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
    
    // set up control 1 to read only 8 msb of each channel (F_READ_BIT)
    // also, set data rate as configured in the consts
    reg = readReg(CTRL_REG1);
    reg = reg | F_READ_BIT; 
    reg = reg & CLEAR_DATA_RATE;
    reg = reg | GOAL_DATA_RATE;
    writeReg(CTRL_REG1, reg);
    

    reg = readReg(CTRL_REG1);
    MMA8452QSetActive(1);

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
function accelRead()
{
    local data = readAccelData();
//    server.log("accels " + data[0] + " " + data[1] + " " + data[2])
    currentLED[0] = data[0];
    currentLED[1] = data[1];
    currentLED[2] = data[2];
    rgbLed.update();

    imp.wakeup(0.15, accelRead);
} 

/************************ General ***************************************/
//imp.setpowersave(true);

agent.on("hug", setHugColor);
//ledHugRamp(); // white hug on boot
MMA8452QReset();
accelRead();

