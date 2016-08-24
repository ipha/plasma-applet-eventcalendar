import QtQuick 2.0
import QtQuick.Controls 1.1
import QtQuick.Layouts 1.1

import org.kde.plasma.calendar 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras

import "utils.js" as Utils
import "shared.js" as Shared

Item {
    id: meteogramView
    width: 400
    height: 100
    property bool cfg_clock_24h: false
    property int cfg_meteogram_hours: 9
    property bool showIconOutline: false
    property bool showGridlines: true
    property alias xAxisScale: graph.xAxisScale
    property int xAxisLabelEvery: 1

    onCfg_clock_24hChanged: {
        graph.gridData = formatXAxisLabels(graph.gridData)
        graph.update();
    }

    onCfg_meteogram_hoursChanged: {
        graph.update();
    }

    Rectangle {
        visible: typeof root === 'undefined'
        color: PlasmaCore.ColorScope.backgroundColor
        anchors.fill: parent
    }

    Item {
        id: graph
        anchors.fill: parent

        property int xAxisLabelHeight: 20
        property int xAxisMin: 0
        property int xAxisMax: 10
        property double xAxisScale: 0.333333333333 // 3 lines per data point
        property int yAxisLabelWidth: 30
        property int yAxisMin: -10
        property int yAxisMax: 20
        property int yAxisScale: 2
        property int yAxisScaleCount: 4
        property double yAxisRainMinScale: 2
        property double yAxisRainMax: 2
        property bool showYAxisRainMax: true

        property int gridX: yAxisLabelWidth
        property int gridX2: width
        property int gridWidth: gridX2 - gridX
        property int gridY: 5
        property int gridY2: height - xAxisLabelHeight
        property int gridHeight: gridY2 - gridY

        // property color scaleColor: "#11000000" // meteogramView.showGridlines ? theme.buttonBackgroundColor : "transparent"
        property color scaleColor: theme.buttonBackgroundColor
        property color labelColor: theme.textColor
        property color precipitationColor: "#acd"
        property color precipitationTextOulineColor: meteogramView.showIconOutline ? theme.backgroundColor : "transparent"
        property color tempAbove0Color: "#900"
        property color tempBelow0Color: "#369"

        Connections {
            target: theme
            onTextColorChanged: { graph.update(); }
            onButtonBackgroundColorChanged: { graph.update(); }
        }

        property variant gridData: []
        property variant yData: []

        onGridDataChanged: {
            xAxisMax = Math.max(1, gridData.length - 1)

            yData = []
            var yDataMin = 0;
            var yDataMax = 1;
            yAxisRainMax = yAxisRainMinScale;
            for (var i = 0; i < gridData.length; i++) {
                var y = gridData[i].y;
                yData.push(y);
                if (i == 0 || y < yDataMin) {
                    yDataMin = y
                }
                if (i == 0 || y > yDataMax) {
                    yDataMax = y
                }
                if (gridData[i].percipitation > yAxisRainMax) {
                    yAxisRainMax = Math.ceil(gridData[i].percipitation)
                }
            }

            yAxisScale = Math.ceil((yDataMax-yDataMin) / (yAxisScaleCount))
            yAxisMin = Math.floor(yDataMin)
            yAxisMax = Math.ceil(yDataMax)
        }

        function updateGridItemAreas() {
            var areas = [];
            // Skip the first gridItem since it's area starts at the edge of the grid.
            for (var i = 1; i < gridData.length; i++) {
                var a = graph.gridPoint(i-2, graph.yAxisMin);
                var b = graph.gridPoint(i-1, graph.yAxisMin);
                var area = {};
                area.areaX = a.x
                area.areaY = a.y
                area.areaWidth = b.x - a.x
                area.areaHeight = graph.gridHeight
                console.log(JSON.stringify(area));
                area.gridItem = gridData[i];
                areas.push(area);
            }
            console.log(JSON.stringify(areas));
            gridDataAreas.model = areas;
        }


        function gridPoint(x, y) {
            return {
                x: (x - xAxisMin) / (xAxisMax - xAxisMin) * gridWidth + gridX,
                y: gridHeight - (y - yAxisMin) / (yAxisMax - yAxisMin) * gridHeight + gridY,
            }
        }

        function update() {
            gridCanvas.requestPaint()
            console.log('updated');
        }

        Item {
            id: layers
            anchors.fill: parent

            Canvas {
                id: gridCanvas
                anchors.fill: parent
                canvasSize.width: parent.width
                canvasSize.height: parent.height
                contextType: '2d'

                function drawLine(x1, y1, x2, y2) {
                    var p1 = graph.gridPoint(x1, y1);
                    var p2 = graph.gridPoint(x2, y2);
                    context.moveTo(p1.x, p1.y);
                    context.lineTo(p2.x, p2.y);
                    context.stroke();
                    // console.log(JSON.stringify(p1), JSON.stringify(p2));
                }

                // http://stackoverflow.com/questions/7054272/how-to-draw-smooth-curve-through-n-points-using-javascript-html5-canvas
                function drawCurve(path) {
                    if (path.length < 3) return;

                    var gridPath = [];
                    for (var i = 0; i < path.length; i++) {
                        var item = path[i];
                        var p = graph.gridPoint(item.x, item.y);
                        gridPath.push(p);
                    }

                    context.beginPath();
                    context.moveTo(gridPath[0].x, gridPath[0].y);

                    // curve from 1 .. n-2
                    for (var i = 1; i < path.length - 2; i++) {
                        var xc = (gridPath[i].x + gridPath[i+1].x) / 2;
                        var yc = (gridPath[i].y + gridPath[i+1].y) / 2;
                        
                        context.quadraticCurveTo(gridPath[i].x, gridPath[i].y, xc, yc);
                    }
                    var n = path.length-1;
                    context.quadraticCurveTo(gridPath[n-1].x, gridPath[n-1].y, gridPath[n].x, gridPath[n].y);

                    context.stroke();
                }

                onPaint: {
                    // var ctx = canvas.getContext("2d");
                    context.reset();
                    if (graph.gridData.length < 2) return;
                    if (graph.yAxisMin == graph.yAxisMax) return;

                    // rain
                    graph.showYAxisRainMax = false
                    var gridDataAreaWidth = 0;
                    for (var i = 1; i < graph.gridData.length; i++) {
                        var item = graph.gridData[i];
                        if (item.percipitation) {
                            graph.showYAxisRainMax = true
                            var rainY = Math.min(item.percipitation, graph.yAxisRainMax) / graph.yAxisRainMax;
                            var a = graph.gridPoint(i-1, graph.yAxisMin);
                            var b = graph.gridPoint(i, graph.yAxisMin);
                            var h = rainY * graph.gridHeight;
                            gridDataAreaWidth = b.x-a.x;
                            context.fillStyle = graph.precipitationColor
                            context.fillRect(a.x, a.y, gridDataAreaWidth, -h);
                        }
                    }

                    // yAxis scale
                    for (var y = graph.yAxisMin; y <= graph.yAxisMax; y += graph.yAxisScale) {
                        context.strokeStyle = graph.scaleColor
                        context.lineWidth = 1;
                        drawLine(graph.xAxisMin, y, graph.xAxisMax, y);

                        // yAxis label: temp
                        var p = graph.gridPoint(graph.xAxisMin, y);
                        context.fillStyle = graph.labelColor
                        context.font = "12px sans-serif"
                        context.textAlign = 'end'
                        var labelText = y + '°';
                        context.fillText(labelText, p.x - 2, p.y + 6)
                    }

                    // xAxis scale
                    for (var x = graph.xAxisMin; x <= graph.xAxisMax; x += graph.xAxisScale) {
                        context.strokeStyle = graph.scaleColor
                        context.lineWidth = 1;
                        drawLine(x, graph.yAxisMin, x, graph.yAxisMax);
                    }
                    for (var i = 0; i < graph.gridData.length; i++) {
                        var item = graph.gridData[i];
                        var p = graph.gridPoint(i, graph.yAxisMin);

                        context.fillStyle = graph.labelColor
                        context.font = "12px sans-serif"
                        context.textAlign = 'center'

                        if (item.xLabel) {
                            context.fillText(item.xLabel, p.x, p.y + 12 + 2);
                        }
                    }


                    // temp
                    // context.strokeStyle = '#900'
                    context.lineWidth = 3;
                    var path = [];
                    var pathMinY;
                    var pathMaxY;
                    for (var i = 0; i < graph.gridData.length; i++) {
                        var item = graph.gridData[i];
                        path.push({ x: i, y: item.y });
                        if (i == 0 || item.y < pathMinY) pathMinY = item.y;
                        if (i == 0 || item.y > pathMaxY) pathMaxY = item.y;
                    }
                    var pZeroY = graph.gridPoint(0, 0).y;
                    var pMaxY = graph.gridPoint(0, pathMinY).y; // y axis gets flipped
                    var pMinY = graph.gridPoint(0, pathMaxY).y; // y axis gets flipped
                    var height = pMaxY - pMinY;
                    var pZeroYRatio = (pZeroY-pMinY) / height;
                    console.log(pMinY, pMaxY)
                    console.log(height)
                    console.log(pZeroY, pZeroYRatio)
                    if (pZeroYRatio <= 0) {
                        context.strokeStyle = graph.tempBelow0Color;
                    } else if (pZeroYRatio >= 1) {
                        context.strokeStyle = graph.tempAbove0Color;
                    } else {
                        var gradient = context.createLinearGradient(0, pMinY, 0, pMaxY);
                        gradient.addColorStop(pZeroYRatio-0.0001, graph.tempAbove0Color);
                        gradient.addColorStop(pZeroYRatio, graph.tempBelow0Color);
                        context.strokeStyle = gradient;
                    }
                    drawCurve(path);


                    // yAxis label: precipitation
                    var lastLabelVisible = false;
                    var lastLabelStaggered = false;
                    for (var i = 1; i < graph.gridData.length; i++) {
                        var item = graph.gridData[i];
                        if (item.percipitation && item.percipitation > 0.3) {
                            var p = graph.gridPoint(i, graph.yAxisMin);
                            var pY = graph.gridY + 6;

                            context.fillStyle = graph.precipitationColor
                            context.font = "12px sans-serif"
                            context.textAlign = 'end'
                            var labelText = (item.percipitation >= 1 ? Math.round(item.percipitation) : item.percipitation.toFixed(1)) + 'mm';
                            context.strokeStyle = graph.precipitationTextOulineColor;
                            context.lineWidth = 3;

                            // Stagger the labels so they don't overlap.
                            var labelWidth = context.measureText(labelText).width + 20; // 12px for padding-left
                            if (gridDataAreaWidth < context.measureText(labelText).width && lastLabelVisible && !lastLabelStaggered) {
                                pY += 12 // 12px
                                lastLabelStaggered = true;
                            } else {
                                lastLabelStaggered = false;
                            }
                            lastLabelVisible = true;
                            

                            context.strokeText(labelText, p.x, pY);
                            context.fillText(labelText, p.x, pY);
                        } else {
                            lastLabelVisible = false;
                            lastLabelStaggered = false;
                        }
                    }
                    // if (graph.showYAxisRainMax) {
                    //     context.fillStyle = graph.precipitationColor
                    //     context.font = "12px sans-serif"
                    //     context.textAlign = 'end'
                    //     var labelText = graph.yAxisRainMax + 'mm';
                    //     context.strokeStyle = graph.precipitationTextOulineColor;
                    //     context.lineWidth = 3;
                    //     context.strokeText(labelText, graph.gridX2, graph.gridY + 6)
                    //     context.fillText(labelText, graph.gridX2, graph.gridY + 6)
                    // }
                    

                    // Area
                    graph.updateGridItemAreas()

                    console.log('painted');
                }

            }


 
            Repeater {
                id: gridDataAreas
                anchors.fill: parent
                model: ListModel {}

                delegate: Rectangle {
                    x: modelData.areaX+modelData.areaWidth
                    y: modelData.areaY-modelData.areaHeight
                    width: modelData.areaWidth
                    height: modelData.areaHeight
                    // color: ["#880", "#008"][index % 2]
                    color: "transparent"

                    PlasmaCore.ToolTipArea {
                        id: tooltip
                        anchors.fill: parent
                        icon: modelData.gridItem.weatherIcon
                        mainText: modelData.gridItem.tooltipMainText
                        subText: modelData.gridItem.tooltipSubText
                        location: PlasmaCore.Types.BottomEdge
                    }

                    FontIcon {
                        id: weatherIcon
                        anchors.centerIn: parent
                        color: PlasmaCore.ColorScope.textColor
                        source: modelData.gridItem.weatherIcon
                        height: 24
                        opacity: tooltip.containsMouse ? 0.1 : 1
                        showOutline: meteogramView.showIconOutline
                    }

                    Component.onCompleted: {
                        console.log(x, y)
                    }
                }

            }


        }
    }

    Component.onCompleted: {
        // graph.gridData = [
        //     {'y': 1},
        //     {'y': 2},
        //     {'y': 3},
        // ]
        graph.update();

        if (typeof popup === "undefined" || typeof root === 'undefined') {
            Utils.getJSON({
                url: 'ForecastGraphData.json'
            }, function(err, hourlyData, xhr) {
                var currentWeatherData = hourlyData.list[0];
                parseWeatherForecast(currentWeatherData, hourlyData)
            });
        }
    }

    function updateWeatherData() {
        var app_id = '99e575d9aa8a8407bcee7693d5912c6a';
        var city_id = 5983720;
        var units = 'metric';
        Shared.fetchHourlyWeatherForecast({
            app_id: app_id,
            city_id: city_id,
            units: units,
        }, function(err, hourlyData, xhr) {
            var currentWeatherData = hourlyData.list[0];
            parseWeatherForecast(currentWeatherData, hourlyData)
        });
    }

    // function onWeatherData(err, data, xhr) {
    //     parseWeatherForecast(data);
    // }
        

    function parseWeatherForecast(currentWeatherData, data) {
        // console.log(JSON.stringify(data, null, '\t'));
        var gData = [];

        function parseDailyWeatherItem(item) {
            var rain = item.rain && item.rain['3h'] || 0;
            var snow = item.snow && item.snow['3h'] || 0;
            var mm = rain + snow;

            // console.log(JSON.stringify(item))
            var tooltipSubText = item.weather[0].description;
            if (mm) {
                tooltipSubText += ' (' + mm + 'mm)';
            }
            tooltipSubText += '<br>' + item.main.temp + '°';

            return {
                y: item.main.temp,
                xTimestamp: item.dt * 1000,
                percipitation: mm,
                tooltipMainText: new Date(item.dt * 1000),
                tooltipSubText: tooltipSubText,
                weatherIcon: item.weather[0].iconName || Shared.weatherIconMap[item.weather[0].icon] || 'weather-severe-alert',
            };
        }

        if (currentWeatherData) {
            gData.push(parseDailyWeatherItem(currentWeatherData));
        } else {
            if (data.list.length > 0) {
                gData.push({
                    y: data.list[0].main.temp,
                    xTimestamp: Date.now(),
                    percipitation: 0,
                });
            }
        }

        for (var i = 0; i < data.list.length; i++) {
            var item = data.list[i];
            gData.push(parseDailyWeatherItem(item));
        }

        // console.log(JSON.stringify(gData, null, '\t'));

        // Only forcast next _ hours
        gData = gData.slice(0, Math.max(3, Math.ceil(meteogramView.cfg_meteogram_hours * meteogramView.xAxisScale) + 1));

        // Format xAxis Labels
        gData = formatXAxisLabels(gData);

        graph.gridData = gData;
        graph.update();
    }

    function formatXAxisLabels(gData) {
        for (var i = 0; i < gData.length; i++) {
            var firstOrLast = i == 0 || i == gData.length-1;
            var labelSkipped = i % Math.ceil(meteogramView.xAxisLabelEvery) != 0;
            // if (i != 0 && i != gData.length-1) {
            if (!firstOrLast && !labelSkipped) {
                var date = new Date(gData[i].xTimestamp);
                var hour = date.getHours();
                var label = '';
                if (meteogramView.cfg_clock_24h) {
                    label += hour
                } else {
                    // 12 hour clock
                    // (3am = 3) (11pm = 11p)
                    label += hour % 12 == 0 ? 12 : hour % 12
                    label += (hour < 12 ? '' : 'p')
                }
                gData[i].xLabel = label;
            } else {
                gData[i].xLabel = '';
            }
        }
        return gData;
    }
}


