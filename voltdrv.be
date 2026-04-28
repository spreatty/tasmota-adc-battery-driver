var DEF_VOLT_CAL = 6.0

def volts()
    import persist
    return tasmota.cmd('Status 10', True)['StatusSNS']['ANALOG']['Voltage7'] * persist.find('volt_cal', DEF_VOLT_CAL)
end

def volt_res()
    return tasmota.cmd('VoltRes', True)['VoltRes']
end

def voltage(cmd, idx, payload, payload_json)
    tasmota.resp_cmnd({"Voltage": volts()})
end
tasmota.add_cmd('Voltage', voltage)

def voltage_cal(cmd, idx, payload, payload_json)
    import persist
    if payload_json == nil
        tasmota.resp_cmnd({"VoltageCal": persist.find('volt_cal', DEF_VOLT_CAL)})
    elif type(payload_json) == 'int' || type(payload_json) == 'real'
        persist.volt_cal = real(payload_json)
        persist.save()
        tasmota.resp_cmnd({"VoltageCal": persist.find('volt_cal', DEF_VOLT_CAL)})
    else
        tasmota.resp_cmnd_error()
    end
end
tasmota.add_cmd('VoltageCal', voltage_cal)

var RESTART_CMD = 'Backlog+Power+Off+%3B+Delay+200+%3B+Power+On'
var grid_check_counter = 0
def grid_check(cmd, idx, payload, payload_json)
    if volts() < 13
        grid_check_counter += 1
        if grid_check_counter == 2
            webclient().begin('http://192.168.3.35/cm?cmnd='+RESTART_CMD).GET()
            grid_check_counter = 0
            tasmota.resp_cmnd({"GridCheck": "Restarted"})
        else
            tasmota.resp_cmnd({"GridCheck": "Countdown"})
        end
    else
        grid_check_counter = 0
        tasmota.resp_cmnd({"GridCheck": "Online"})
    end
end
tasmota.add_cmd('GridCheck', grid_check)

var MEASURES_IN_SEC = 20, MEASURES_IN_5SEC = MEASURES_IN_SEC * 5, MEASURES_IN_10SEC = MEASURES_IN_SEC * 10
var STABLE_THRESHOLD = 0.03

class VoltageDriver
    var volts, measures
    var avg, lo, hi
    var avg5, lo5, hi5
    var avg10, lo10, hi10
    var stable

    def init()
        self.volts = volts()
        self.measures = []
        for i: 1 .. MEASURES_IN_10SEC
            self.measures.push(self.volts)
        end
        self.avg = self.volts
        self.lo = self.volts
        self.hi = self.volts
        self.avg5 = self.volts
        self.lo5 = self.volts
        self.hi5 = self.volts
        self.avg10 = self.volts
        self.lo10 = self.volts
        self.hi10 = self.volts
        self.stable = self.volts
    end

    def every_50ms()
        self.volts = volts()
        self.measures.pop()
        self.measures.insert(0, self.volts)

        var lo = self.measures[0]
        var hi = self.measures[0]
        var sum = 0.0
        for i: 0 .. self.measures.size() - 1
            if i == MEASURES_IN_SEC
                self.avg = sum / i
                self.lo = lo
                self.hi = hi
            elif i == MEASURES_IN_5SEC
                self.avg5 = sum / i
                self.lo5 = lo
                self.hi5 = hi
            end
            sum += self.measures[i]
            if self.measures[i] < lo lo = self.measures[i] end
            if self.measures[i] > hi hi = self.measures[i] end
        end
        self.avg10 = sum / self.measures.size()
        self.lo10 = lo
        self.hi10 = hi
        
        if self.avg5 < self.stable - STABLE_THRESHOLD || self.avg5 > self.stable + STABLE_THRESHOLD
            self.stable = self.avg5
        end
    end

    def web_sensor()
        import string
        var vform = '%.'+str(volt_res())+'f V'
        tasmota.web_send_decimal(string.format(
            '{s}Voltage{m}'+vform+'{e}'..
            '{s}Stabilised{m}'+vform+'{e}',
            self.volts, self.stable))
        tasmota.web_send_decimal(string.format(
            '{s}Avg 1s Voltage{m}'+vform+'{e}'..
            '{s}Low 1s Voltage{m}'+vform+'{e}'..
            '{s}High 1s Voltage{m}'+vform+'{e}',
            self.avg, self.lo, self.hi))
        tasmota.web_send_decimal(string.format(
            '{s}Avg 5s Voltage{m}'+vform+'{e}'..
            '{s}Low 5s Voltage{m}'+vform+'{e}'..
            '{s}High 5s Voltage{m}'+vform+'{e}',
            self.avg5, self.lo5, self.hi5))
        tasmota.web_send_decimal(string.format(
            '{s}Avg 10s Voltage{m}'+vform+'{e}'..
            '{s}Low 10s Voltage{m}'+vform+'{e}'..
            '{s}High 10s Voltage{m}'+vform+'{e}',
            self.avg10, self.lo10, self.hi10))
    end

    def json_append()
        if !self.volts return nil end
        import string
        tasmota.response_append(string.format(
            ",\"Voltage\":{\"V\":%f,\"STABLE\":%f"..
            ",\"AVG\":%f,\"LO\":%f,\"HI\":%f"..
            ",\"AVG5\":%f,\"LO5\":%f,\"HI5\":%f"..
            ",\"AVG10\":%f,\"LO10\":%f,\"HI10\":%f"..
            "}",
            self.volts, self.stable,
            self.lo, self.hi, self.avg,
            self.lo5, self.hi5, self.avg5,
            self.lo10, self.hi10, self.avg10))
    end
end

var drv = VoltageDriver()
tasmota.add_driver(drv)
