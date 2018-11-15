import QtQuick 2.1
import QtQuick.Layouts 1.3
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponent
import org.kde.kcoreaddons 1.0 as KCoreAddons

Item {
	id: widget

	AppletConfig { id: config }

	// https://github.com/KDE/plasma-workspace/blob/master/dataengines/powermanagement/powermanagementengine.h
	// https://github.com/KDE/plasma-workspace/blob/master/dataengines/powermanagement/powermanagementengine.cpp
	PlasmaCore.DataSource {
		id: pmSource
		engine: "powermanagement"
		connectedSources: sources // basicSourceNames == ["Battery", "AC Adapter", "Sleep States", "PowerDevil", "Inhibitions"]
		onSourceAdded: {
			// console.log('onSourceAdded', source)
			disconnectSource(source)
			connectSource(source)
		}
		onSourceRemoved: {
			disconnectSource(source)
		}

		function log() {
			for (var i = 0; i < pmSource.sources.length; i++) {
				var sourceName = pmSource.sources[i]
				var source = pmSource.data[sourceName]
				for (var key in source) {
					console.log('pmSource.data["'+sourceName+'"]["'+key+'"] =', source[key])
				}
			}
		}
	}

	function getData(sourceName, key, def) {
		var source = pmSource.data[sourceName]
		if (typeof source === 'undefined') {
			return def;
		} else {
			var value = source[key]
			if (typeof value === 'undefined') {
				return def;
			} else {
				return value;
			}
		}
	}

	readonly property bool pluggedIn: getData('AC Adapter', 'Plugged in', false)

	readonly property bool hasBattery: getData('Battery', 'Has Battery', false)
	readonly property bool hasCumulative: getData('Battery', 'Has Cumulative', false)
	// readonly property int remainingTime: getData('Battery', 'Remaining msec', 0)

	property string cumulativeName: 'Battery'
	property int cumulativeRemainingTime: getData(cumulativeName, 'Remaining msec', 0)

	property string primaryBatteryName: 'Battery0'
	property bool primaryBatteryIsPowerSuppy: getData(primaryBatteryName, 'Is Power Supply', false)
	property string primaryBatteryState: getData(primaryBatteryName, 'State', false)
	property int primaryBatteryPercent: getData(primaryBatteryName, 'Percent', 100)
	// Capacity
	// Vendor
	// Product
	property string secondaryBatteryName: 'Battery1'
	property bool secondaryBatteryIsPowerSuppy: getData(secondaryBatteryName, 'Is Power Supply', false)
	property string secondaryBatteryState: getData(secondaryBatteryName, 'State', false)
	property int secondaryBatteryPercent: getData(secondaryBatteryName, 'Percent', 100)


	readonly property bool isLidPresent: getData('PowerDevil', 'Is Lid Present', false)
	readonly property bool triggersLidAction: getData('PowerDevil', 'Triggers Lid Action', false)

	readonly property bool isScreenBrightnessAvailable: getData('PowerDevil', 'Screen Brightness Available', false)
	readonly property int maxScreenBrightness: getData('PowerDevil', 'Maximum Screen Brightness', 0)
	readonly property int minScreenBrightness: (maxScreenBrightness > 100 ? 1 : 0)
	property int screenBrightness: getData('PowerDevil', 'Screen Brightness', maxScreenBrightness)

	readonly property bool isKeyboardBrightnessAvailable: getData('PowerDevil', 'Keyboard Brightness Available', false)

	// Debugging
	property bool testing: false
	// Timer {
	// 	interval: 3000
	// 	running: widget.testing
	// 	repeat: true
	// 	triggeredOnStart: false
	// 	onTriggered: {
	// 		console.log('-----', Date.now())
	// 		pmSource.log()
	// 	}
	// }
	Timer {
		interval: 400
		running: widget.testing
		repeat: true
		onTriggered: {
			if (primaryBatteryState == "Charging") {
				primaryBatteryPercent += 10

				if (primaryBatteryPercent >= 100) {
					primaryBatteryState = "FullyCharged"
				}
			} else if (primaryBatteryState == "FullyCharged") {
				primaryBatteryState = "Discharging"
			} else if (primaryBatteryState == "Discharging") {
				primaryBatteryPercent -= 10

				if (primaryBatteryPercent <= 0) {
					primaryBatteryState = "Charging"
				}
			}
			cumulativeRemainingTime = primaryBatteryPercent * 60 * 1000
			console.log(primaryBatteryState, primaryBatteryPercent)
		}
	}
	Component.onCompleted: {
		if (testing) {
			primaryBatteryState = "Charging"
			primaryBatteryPercent = 80
			cumulativeRemainingTime = 80 * 60 * 1000
		}
	}

	property bool primaryBatteryLowPower: primaryBatteryPercent <= config.lowBatteryPercent
	property color primaryTextColor: {
		if (primaryBatteryLowPower) {
			return config.lowBatteryColor
		} else {
			return config.normalColor
		}
	}

	Plasmoid.compactRepresentation: Item {
		id: panelItem

		Layout.minimumWidth: gridLayout.implicitWidth
		Layout.preferredWidth: gridLayout.implicitWidth

		Layout.minimumHeight: gridLayout.implicitHeight
		Layout.preferredHeight: gridLayout.implicitHeight

		// property int textHeight: Math.max(6, Math.min(panelItem.height, 16 * units.devicePixelRatio))
		property int textHeight: 12 * units.devicePixelRatio
		// onTextHeightChanged: console.log('textHeight', textHeight)

		GridLayout {
			id: gridLayout
			anchors.fill: parent

			// The rect around the Text items in the vertical layout should provide 2 pixels above
			// and below. Adding extra space will make the space between the percentage and time left
			// labels look bigger than the space between the icon and the percentage.
			// So for vertical layouts, we'll add the spacing to just the icon.
			property int spacing: 4 * units.devicePixelRatio
			columnSpacing: spacing
			rowSpacing: 0

			property bool useVerticalLayout: plasmoid.formFactor == PlasmaCore.Types.Vertical
			columns: useVerticalLayout ? 1 : 6

			Item {
				id: batteryIconContainer
				visible: plasmoid.configuration.showBatteryIcon
				anchors.left: gridLayout.useVerticalLayout ? parent.left : undefined
				anchors.right: gridLayout.useVerticalLayout ? parent.right : undefined
				width: 22 * units.devicePixelRatio
				height: 12 * units.devicePixelRatio + (gridLayout.useVerticalLayout ? gridLayout.spacing : 0)

				BreezeBatteryIcon {
					id: batteryIcon
					width: Math.min(parent.width, 22 * units.devicePixelRatio)
					height: Math.min(parent.height, 12 * units.devicePixelRatio)
					anchors.centerIn: parent
					charging: primaryBatteryState == "Charging"
					charge: primaryBatteryPercent
					normalColor: config.normalColor
					chargingColor: config.chargingColor
					lowBatteryColor: config.lowBatteryColor
					lowBatteryPercent: plasmoid.configuration.lowBatteryPercent
				}
			}


			PlasmaComponent.Label {
				id: percentText
				visible: plasmoid.configuration.showPercentage
				anchors.left: gridLayout.useVerticalLayout ? parent.left : undefined
				anchors.right: gridLayout.useVerticalLayout ? parent.right : undefined
				// Layout.fillWidth: true
				text: {
					if (primaryBatteryPercent > 0) {
						// return KCoreAddons.Format.formatDuration(remainingTime, KCoreAddons.FormatTypes.HideSeconds);
						return '' + primaryBatteryPercent + '%'
					} else {
						return '100%';
					}
				}
				font.pointSize: -1
				font.pixelSize: panelItem.textHeight
				fontSizeMode: Text.Fit
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
				color: primaryTextColor

				// Rectangle { border.color: "#ff0"; border.width: 1; anchors.fill: parent; color: "transparent"}
			}

			Item {
				id: secondaryBatteryIconContainer
				visible: plasmoid.configuration.showBatteryIcon
				anchors.left: gridLayout.useVerticalLayout ? parent.left : undefined
				anchors.right: gridLayout.useVerticalLayout ? parent.right : undefined
				width: 22 * units.devicePixelRatio
				height: 12 * units.devicePixelRatio + (gridLayout.useVerticalLayout ? gridLayout.spacing : 0)

				BreezeBatteryIcon {
					id: batteryTwoIcon
					width: Math.min(parent.width, 22 * units.devicePixelRatio)
					height: Math.min(parent.height, 12 * units.devicePixelRatio)
					anchors.centerIn: parent
					charging: secondaryBatteryState == "Charging"
					charge: secondaryBatteryPercent
					normalColor: config.normalColor
					chargingColor: config.chargingColor
					lowBatteryColor: config.lowBatteryColor
					lowBatteryPercent: plasmoid.configuration.lowBatteryPercent
				}
			}


			PlasmaComponent.Label {
				id: secondaryPercentText
				visible: plasmoid.configuration.showPercentage
				anchors.left: gridLayout.useVerticalLayout ? parent.left : undefined
				anchors.right: gridLayout.useVerticalLayout ? parent.right : undefined
				// Layout.fillWidth: true
				text: {
					if (secondaryBatteryPercent > 0) {
						// return KCoreAddons.Format.formatDuration(remainingTime, KCoreAddons.FormatTypes.HideSeconds);
						return '' + secondaryBatteryPercent + '%'
					} else {
						return '100%';
					}
				}
				font.pointSize: -1
				font.pixelSize: panelItem.textHeight
				fontSizeMode: Text.Fit
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
				color: primaryTextColor

				// Rectangle { border.color: "#ff0"; border.width: 1; anchors.fill: parent; color: "transparent"}
			}

			PlasmaComponent.Label {
				id: timeLeftText
				visible: plasmoid.configuration.showTimeLeft
				anchors.left: gridLayout.useVerticalLayout ? parent.left : undefined
				anchors.right: gridLayout.useVerticalLayout ? parent.right : undefined
				text: {
					if (cumulativeRemainingTime > 0) {
						if (plasmoid.configuration.timeLeftFormat == '69m') {
							return '' + Math.floor(cumulativeRemainingTime / (60 * 1000)) + 'm'
						} else { // Empty string
							return KCoreAddons.Format.formatDuration(cumulativeRemainingTime, KCoreAddons.FormatTypes.HideSeconds)
						}
					} else {
						return '';
					}
				}
				font.pointSize: -1
				font.pixelSize: panelItem.textHeight
				fontSizeMode: Text.Fit
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
				color: primaryTextColor

				// Rectangle { border.color: "#f00"; border.width: 1; anchors.fill: parent; color: "transparent"}
			}
		}
	}


}
