using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;
using Toybox.UserProfile as UserProfile;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Gregorian;

//! @author Roelof Koelewijn - Many thanks to Konrad Paumann for the code for the dataFields check out his awsome runningfields Datafield
class HeartRateRunner extends App.AppBase {

    function getInitialView() {
        var view = new HeartRateRunnerView();
        return [ view ];
    }
}

//! DataFields that shows some infos by @author Konrad Paumann
//!
//! HeartRateZones
//! @author Roelof Koelewijn
class HeartRateRunnerView extends Ui.DataField {

    hidden const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    hidden const HEADER_FONT = Graphics.FONT_XTINY;
    hidden const VALUE_FONT = Graphics.FONT_NUMBER_MEDIUM;
    hidden const ZERO_TIME = "0:00";
    hidden const ZERO_DISTANCE = "0.00";
    
    hidden var kmOrMileInMeters = 1000;
    hidden var is24Hour = true;
    hidden var distanceUnits = System.UNIT_METRIC;
    hidden var textColor = Graphics.COLOR_BLACK;
    hidden var inverseTextColor = Graphics.COLOR_WHITE;
    hidden var backgroundColor = Graphics.COLOR_WHITE;
    hidden var inverseBackgroundColor = Graphics.COLOR_BLACK;
    hidden var inactiveGpsBackground = Graphics.COLOR_LT_GRAY;
    hidden var batteryBackground = Graphics.COLOR_WHITE;
    hidden var batteryColor1 = Graphics.COLOR_GREEN;
    hidden var hrColor = Graphics.COLOR_RED;
    hidden var headerColor = Graphics.COLOR_DK_GRAY;
        
    hidden var paceStr, avgPaceStr, hrStr, distanceStr, durationStr;
    
    hidden var paceData = new DataQueue(10);
    hidden var avgSpeed= 0;
    hidden var hr = 0;
    hidden var distance = 0;
    hidden var elapsedTime = 0;
    hidden var gpsSignal = 0;
    hidden var maxHr = 0;
    
    hidden var hasBackgroundColorOption = false;
    
    function initialize() {
        DataField.initialize();
        var profile = UserProfile.getProfile();
		var userAge = Gregorian.info(Time.now(), Time.FORMAT_SHORT).year - profile.birthYear;
		maxHr = 217 - (0.85 * userAge);
    }

    //! The given info object contains all the current workout
    function compute(info) {
        if (info.currentSpeed != null) {
            paceData.add(info.currentSpeed);
        } else {
            paceData.reset();
        }
        
        avgSpeed = info.averageSpeed != null ? info.averageSpeed : 0;
        elapsedTime = info.elapsedTime != null ? info.elapsedTime : 0;        
        hr = info.currentHeartRate != null ? info.currentHeartRate : 0;
        distance = info.elapsedDistance != null ? info.elapsedDistance : 0;
        gpsSignal = info.currentLocationAccuracy;
    }
    
    function onLayout(dc) {
        setDeviceSettingsDependentVariables();
        onUpdate(dc);
    }
    
    function onUpdate(dc) {
        setColors();
        // reset background
        var width = dc.getWidth();
    	var height = dc.getHeight();
        dc.setColor(backgroundColor, backgroundColor);
        dc.fillRectangle(0, 0, width, height);
        
        drawValues(dc);
    }

    function setDeviceSettingsDependentVariables() {
        hasBackgroundColorOption = (self has :getBackgroundColor);
        
        distanceUnits = System.getDeviceSettings().distanceUnits;
        if (distanceUnits == System.UNIT_METRIC) {
            kmOrMileInMeters = 1000;
        } else {
            kmOrMileInMeters = 1610;
        }
        is24Hour = System.getDeviceSettings().is24Hour;
        
        paceStr = Ui.loadResource(Rez.Strings.pace);
        avgPaceStr = Ui.loadResource(Rez.Strings.avgpace);
        hrStr = Ui.loadResource(Rez.Strings.hr);
        distanceStr = Ui.loadResource(Rez.Strings.distance);
        durationStr = Ui.loadResource(Rez.Strings.duration);
    }
    
    function setColors() {
        if (hasBackgroundColorOption) {
            backgroundColor = getBackgroundColor();
            textColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
            inverseTextColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_WHITE;
            inverseBackgroundColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_DK_GRAY: Graphics.COLOR_BLACK;
            hrColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_BLUE : Graphics.COLOR_RED;
            headerColor = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY: Graphics.COLOR_DK_GRAY;
            batteryColor1 = (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_GREEN;
        }
    }
        
    function drawValues(dc) {
        //time
        var clockTime = System.getClockTime();
        var time, ampm;
        if (is24Hour) {
            time = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%.2d")]);
            ampm = "";
        } else {
            time = Lang.format("$1$:$2$", [computeHour(clockTime.hour), clockTime.min.format("%.2d")]);
            ampm = (clockTime.hour < 12) ? "am" : "pm";
        }
        
        //pace
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(60, 74, VALUE_FONT, getMinutesPerKmOrMile(computeAverageSpeed()), CENTER);
        
        //hr
        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(109, 30, Graphics.FONT_NUMBER_MILD, hr.format("%d"), CENTER);
        
        //apace
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(60, 134, VALUE_FONT, getMinutesPerKmOrMile(avgSpeed), CENTER);
        
        //distance
        var distStr;
        if (distance > 0) {
            var distanceKmOrMiles = distance / kmOrMileInMeters;
            if (distanceKmOrMiles < 100) {
                distStr = distanceKmOrMiles.format("%.2f");
            } else {
                distStr = distanceKmOrMiles.format("%.1f");
            }
        } else {
            distStr = ZERO_DISTANCE;
        }
        dc.drawText(155 , 74, VALUE_FONT, distStr, CENTER);
        
        //duration
        var duration;
        if (elapsedTime != null && elapsedTime > 0) {
            var hours = null;
            var minutes = elapsedTime / 1000 / 60;
            var seconds = elapsedTime / 1000 % 60;
            
            if (minutes >= 60) {
                hours = minutes / 60;
                minutes = minutes % 60;
            }
            
            if (hours == null) {
                duration = minutes.format("%d") + ":" + seconds.format("%02d");
            } else {
                duration = hours.format("%d") + ":" + minutes.format("%02d") + ":" + seconds.format("%02d");
            }
        } else {
            duration = ZERO_TIME;
        } 
        dc.drawText(155, 134, VALUE_FONT, duration, CENTER);
        
        //signs background
        dc.setColor(inverseBackgroundColor, inverseBackgroundColor);
        dc.fillRectangle(0,180,218,38);
        
        // time
        dc.setColor(inverseTextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(109, 207, HEADER_FONT, time, CENTER);
        
        drawBattery(System.getSystemStats().battery, dc, 64, 186, 25, 15);
        
        // gps 
        if (gpsSignal < 2) {
            drawGpsSign(dc, 136, 181, inactiveGpsBackground, inactiveGpsBackground, inactiveGpsBackground);
        } else if (gpsSignal == 2) {
            drawGpsSign(dc, 136, 181, batteryColor1, inactiveGpsBackground, inactiveGpsBackground);
        } else if (gpsSignal == 3) {          
            drawGpsSign(dc, 136, 181, batteryColor1, batteryColor1, inactiveGpsBackground);
        } else {
            drawGpsSign(dc, 136, 181, batteryColor1, batteryColor1, batteryColor1);
        }
        
        // headers:
        dc.setColor(headerColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(65, 42, HEADER_FONT, paceStr, CENTER);
        dc.drawText(65, 169, HEADER_FONT, avgPaceStr, CENTER);
        dc.drawText(155, 42, HEADER_FONT, distanceStr, CENTER);
        dc.drawText(155, 169, HEADER_FONT, durationStr, CENTER);
        
        //grid
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(0, 108, dc.getWidth(), 108);
        
        //RKO Arc
		var width = dc.getWidth();
    	var height = dc.getHeight();
		drawZoneBarsArcs(dc, (height/2)+1, width/2, height/2, hr); //radius, center x, center y
    }
    
    function drawBattery(battery, dc, xStart, yStart, width, height) {                
        dc.setColor(batteryBackground, inactiveGpsBackground);
        dc.fillRectangle(xStart, yStart, width, height);
        if (battery < 10) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xStart+3 + width / 2, yStart + 6, HEADER_FONT, format("$1$%", [battery.format("%d")]), CENTER);
        }
        
        if (battery < 10) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        } else if (battery < 30) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(batteryColor1, Graphics.COLOR_TRANSPARENT);
        }
        dc.fillRectangle(xStart + 1, yStart + 1, (width-2) * battery / 100, height - 2);
            
        dc.setColor(batteryBackground, batteryBackground);
        dc.fillRectangle(xStart + width - 1, yStart + 3, 4, height - 6);
    }
    
    function drawGpsSign(dc, xStart, yStart, color1, color2, color3) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(xStart - 1, yStart + 11, 8, 10);
        dc.setColor(color1, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.fillRectangle(xStart, yStart + 12, 6, 8);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(xStart + 6, yStart + 7, 8, 14);
        dc.setColor(color2, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.fillRectangle(xStart + 7, yStart + 8, 6, 12);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(xStart + 13, yStart + 3, 8, 18);
        dc.setColor(color3, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.fillRectangle(xStart + 14, yStart + 4, 6, 16);
    }
    
    function computeAverageSpeed() {
        var size = 0;
        var data = paceData.getData();
        var sumOfData = 0.0;
        for (var i = 0; i < data.size(); i++) {
            if (data[i] != null) {
                sumOfData = sumOfData + data[i];
                size++;
            }
        }
        if (sumOfData > 0) {
            return sumOfData / size;
        }
        return 0.0;
    }
    
    function computeHour(hour) {
        if (hour < 1) {
            return hour + 12;
        }
        if (hour >  12) {
            return hour - 12;
        }
        return hour;      
    }
    
    //! convert to integer - round ceiling 
    function toNumberCeil(float) {
        var floor = float.toNumber();
        if (float - floor > 0) {
            return floor + 1;
        }
        return floor;
    }
    
    function getMinutesPerKmOrMile(speedMetersPerSecond) {
        if (speedMetersPerSecond != null && speedMetersPerSecond > 0.2) {
            var metersPerMinute = speedMetersPerSecond * 60.0;
            var minutesPerKmOrMilesDecimal = kmOrMileInMeters / metersPerMinute;
            var minutesPerKmOrMilesFloor = minutesPerKmOrMilesDecimal.toNumber();
            var seconds = (minutesPerKmOrMilesDecimal - minutesPerKmOrMilesFloor) * 60;
            return minutesPerKmOrMilesDecimal.format("%2d") + ":" + seconds.format("%02d");
        }
        return ZERO_TIME;
    }
    
    //! @author Roelof Koelewijn
    //function for arc
	function drawZoneBarsArcs(dc, radius, centerX, centerY, hr){
		var angle;
		var lessAngle;
		
		var zone1CircleWidth = 7;
		var zone2CircleWidth = 7;
		var zone3CircleWidth = 7;
		var zone4CircleWidth = 7;
		var zone5CircleWidth = 7;
		
		var zone1 = maxHr * 0.64; 
	    var zone2 = maxHr * 0.72; 
	    var zone3 = maxHr * 0.79; 
	    var zone4 = maxHr * 0.87;
	    var zone5 = maxHr * 0.94;
	    var hrmax = maxHr;
	    
	    var zonedegree = 54 / (zone2 - zone1); //3.9
		
		if(hr >= zone1 && hr < zone2){
			zone1CircleWidth = 15;
			zonedegree = 54 / (zone2 - zone1);
			zonedegree = zonedegree * (zone2-hr);
		}else if(hr >= zone2 && hr < zone3){
			zone2CircleWidth = 15;
			zonedegree = 54 / (zone3 - zone2);
			zonedegree = zonedegree * (zone3-hr);
		}else if(hr >= zone3 && hr < zone4){
			zonedegree = 54 / (zone4 - zone3);
			zone3CircleWidth = 15;
			zonedegree = zonedegree * (zone4-hr);
		}else if(hr >= zone4 && hr < zone5){
			zonedegree = 54 / (zone5 - zone4);
			zone4CircleWidth = 15;
			zonedegree = zonedegree * (zone5-hr);
		}else if(hr >= zone5){
			zonedegree = 54 / (hrmax - zone5);
			zone5CircleWidth = 15;
			zonedegree = zonedegree * (hrmax-hr);
		}
				
		//zone 1
		dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(zone1CircleWidth);
		dc.drawArc(centerX, centerY, radius - zone1CircleWidth/2, 1, 220, 166);
		if(hr >= zone1 && hr < zone2){
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(20);
			dc.drawArc(centerX, centerY, radius - 8, 0, 166 + zonedegree - 3, 166 + zonedegree + 1);
			dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(17);
			dc.drawArc(centerX, centerY, radius - 8, 0, 166 + zonedegree - 2, 166 + zonedegree);
		}
		
		//zone 2
		dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(zone2CircleWidth);
		dc.drawArc(centerX, centerY, radius - zone2CircleWidth/2, 1, 166, 112);
		if(hr >= zone2 && hr < zone3){
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(20);
			dc.drawArc(centerX, centerY, radius - 8, 0, 112 + zonedegree - 3, 112 + zonedegree + 1);
			dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(17);
			dc.drawArc(centerX, centerY, radius - 8, 0, 112 + zonedegree -2, 112 + zonedegree);
		}
		
		//zone 3 OK
		dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(zone3CircleWidth);
		dc.drawArc(centerX, centerY, radius - zone3CircleWidth/2, 1, 112, 58);
		if(hr >= zone3 && hr < zone4){
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(20);
			dc.drawArc(centerX, centerY, radius - 8, 0, 58 + zonedegree - 3, 58 + zonedegree + 1);
			dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(17);
			dc.drawArc(centerX, centerY, radius - 8, 0, 58 + zonedegree - 2, 58 + zonedegree);
		}
		
		//zone 4
		dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(zone4CircleWidth);
		dc.drawArc(centerX, centerY, radius - zone4CircleWidth/2, 1, 58, 4);
		if(hr >= zone4 && hr < zone5){
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(20);
			dc.drawArc(centerX, centerY, radius - 8, 0, 4 + zonedegree - 3, 4 + zonedegree + 1);
			dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(17);
			dc.drawArc(centerX, centerY, radius - 8, 0, 4 + zonedegree - 2, 4 + zonedegree);
		}
		
		//zone 5
		dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
		dc.setPenWidth(zone5CircleWidth);
		dc.drawArc(centerX, centerY, radius - zone5CircleWidth/2, 1, 4, 320);
		if(hr >= zone5){
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(20);
			if((320 + zonedegree) < 360){
				dc.drawArc(centerX, centerY, radius - 8, 0, 320 + zonedegree - 3, 320 + zonedegree + 1);
			}else{
				dc.drawArc(centerX, centerY, radius - 8, 0, -50 + zonedegree - 3 , -50 + zonedegree + 1);
			}
			dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(17);
			if((320 + zonedegree) < 360){
				dc.drawArc(centerX, centerY, radius - 8, 0, 320 + zonedegree - 2, 320 + zonedegree);
			}else{
				dc.drawArc(centerX, centerY, radius - 8, 0, -50 + zonedegree -2 , -50 + zonedegree);
			}
		}
		
		//! @author Roelof Koelewijn
		//function for arrow
		//position 1 - zone 1 (14)
		//fillPolygon(dc, 40, 170, 2.5, [[1,1], [1,16], [20,8]]);
		//position 14 - zone 1 (14)
		//fillPolygon(dc, 16, 103, 3.5, [[1,1], [1,16], [20,8]]);
	}
	
	//! @author Roelof Koelewijn
	//function for arrow
	function fillPolygon(dc, dx, dy, theta, points) {
	    var sin = Math.sin(theta);
	    var cos = Math.cos(theta);
	
	    for (var i = 0; i < points.size(); ++i) {
	        var x = (points[i][0] * cos) - (points[i][1] * sin) + dx;
	        var y = (points[i][0] * sin) + (points[i][1] * cos) + dy;
	
	        points[i][0] = x;
	        points[i][1] = y;
	    }
		dc.setColor(Graphics.COLOR_PINK, Graphics.COLOR_TRANSPARENT);
	    dc.fillPolygon(points);
	}
}

//! A circular queue implementation.
//! @author Konrad Paumann
class DataQueue {

    //! the data array.
    hidden var data;
    hidden var maxSize = 0;
    hidden var pos = 0;

    //! precondition: size has to be >= 2
    function initialize(arraySize) {
        data = new[arraySize];
        maxSize = arraySize;
    }
    
    //! Add an element to the queue.
    function add(element) {
        data[pos] = element;
        pos = (pos + 1) % maxSize;
    }
    
    //! Reset the queue to its initial state.
    function reset() {
        for (var i = 0; i < data.size(); i++) {
            data[i] = null;
        }
        pos = 0;
    }
    
    //! Get the underlying data array.
    function getData() {
        return data;
    }
}