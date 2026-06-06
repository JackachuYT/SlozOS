import QtQuick 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width:  Screen.width  || 1920
    height: Screen.height || 1080

    // ── Background gradient ───────────────────────────────────────────────────
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: "#0F0F20" }
        GradientStop { position: 1.0; color: "#060610" }
    }

    // Ambient blue glow (radial, off-centre like macOS Tahoe)
    Rectangle {
        width:  root.width  * 0.55
        height: root.height * 0.55
        x: root.width  * 0.22
        y: root.height * 0.22
        radius: width / 2
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            // Simulate radial by stacking translucent circles
            Repeater {
                model: 12
                Rectangle {
                    property real ratio: (12 - index) / 12.0
                    width:  parent.width  * ratio
                    height: parent.height * ratio
                    x: (parent.width  - width)  / 2
                    y: (parent.height - height) / 2
                    radius: width / 2
                    color: Qt.rgba(0, 0.38, 1.0, 0.007)
                }
            }
        }
    }

    // Subtle dot grid
    Canvas {
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = "rgba(255,255,255,0.04)";
            for (var gx = 0; gx < width;  gx += 50)
            for (var gy = 0; gy < height; gy += 50) {
                ctx.beginPath();
                ctx.arc(gx, gy, 1, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    // ── Clock (top-right) ─────────────────────────────────────────────────────
    Column {
        anchors { right: parent.right; top: parent.top; margins: 48 }
        spacing: 4

        Text {
            id: clockTime
            anchors.right: parent.right
            text: Qt.formatTime(new Date(), "hh:mm")
            font { family: "Inter"; pixelSize: 58; weight: Font.Thin }
            color: "#FFFFFF"
            opacity: 0.88
        }
        Text {
            id: clockDate
            anchors.right: parent.right
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
            font { family: "Inter"; pixelSize: 16; weight: Font.Light }
            color: "#FFFFFF"
            opacity: 0.45
        }

        Timer {
            interval: 10000; running: true; repeat: true
            onTriggered: {
                clockTime.text = Qt.formatTime(new Date(), "hh:mm");
                clockDate.text = Qt.formatDate(new Date(), "dddd, MMMM d");
            }
        }
    }

    // ── Login card (glass panel) ───────────────────────────────────────────────
    Rectangle {
        id: card
        width:  380
        height: sessionRow.visible ? 490 : 450
        anchors.centerIn: parent

        color:  Qt.rgba(0, 0, 0, 0.52)
        radius: 22
        border { color: Qt.rgba(1, 1, 1, 0.18); width: 1 }

        // Top-edge glass highlight
        Rectangle {
            width:  parent.width - 2
            height: 1
            anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter }
            color: Qt.rgba(1, 1, 1, 0.20)
        }

        Behavior on height { NumberAnimation { duration: 180 } }

        ColumnLayout {
            anchors { fill: parent; margins: 40 }
            spacing: 0

            // Sloth mascot logo
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: Qt.resolvedUrl("logo.png")
                width:  110
                height: 110
                fillMode: Image.PreserveAspectFit
                smooth: true
                opacity: 0.92
            }

            Item { Layout.preferredHeight: 10 }

            // SlozOS wordmark
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "SlozOS"
                font { family: "Inter"; pixelSize: 22; weight: Font.Light; letterSpacing: 5 }
                color: "#FFFFFF"
                opacity: 0.82
            }

            Item { Layout.preferredHeight: 24 }

            // ── Username ──────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 46
                radius: 11
                color:  Qt.rgba(1, 1, 1, 0.07)
                border { color: userField.activeFocus ? Qt.rgba(0, 0.47, 1.0, 0.75)
                                                      : Qt.rgba(1, 1, 1, 0.10); width: 1 }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                TextInput {
                    id: userField
                    anchors { left: parent.left; right: parent.right
                              verticalCenter: parent.verticalCenter; margins: 14 }
                    text: userModel.lastUser
                    font { family: "Inter"; pixelSize: 14 }
                    color: "#FFFFFF"
                    selectionColor: Qt.rgba(0, 0.47, 1.0, 0.45)
                    clip: true
                    KeyNavigation.tab: passField
                    Keys.onReturnPressed: passField.forceActiveFocus()

                    Text {
                        anchors.fill: parent
                        text: "Username"
                        font: parent.font
                        color: Qt.rgba(1, 1, 1, 0.30)
                        visible: parent.text === ""
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item { Layout.preferredHeight: 10 }

            // ── Password ──────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 46
                radius: 11
                color:  Qt.rgba(1, 1, 1, 0.07)
                border { color: passField.activeFocus ? Qt.rgba(0, 0.47, 1.0, 0.75)
                                                      : Qt.rgba(1, 1, 1, 0.10); width: 1 }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                TextInput {
                    id: passField
                    anchors { left: parent.left; right: parent.right
                              verticalCenter: parent.verticalCenter; margins: 14 }
                    echoMode: TextInput.Password
                    font { family: "Inter"; pixelSize: 14 }
                    color: "#FFFFFF"
                    selectionColor: Qt.rgba(0, 0.47, 1.0, 0.45)
                    clip: true
                    KeyNavigation.tab: loginBtn
                    Keys.onReturnPressed: doLogin()

                    Text {
                        anchors.fill: parent
                        text: "Password"
                        font: parent.font
                        color: Qt.rgba(1, 1, 1, 0.30)
                        visible: parent.text === ""
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }

            // ── Sign in button ────────────────────────────────────────────────
            Rectangle {
                id: loginBtn
                Layout.fillWidth: true
                height: 46
                radius: 11
                color: loginHover.containsMouse ? Qt.rgba(0, 0.50, 1.0, 0.92)
                                                : Qt.rgba(0, 0.47, 1.0, 0.78)
                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    text: "Sign In"
                    font { family: "Inter"; pixelSize: 14; weight: Font.Medium }
                    color: "#FFFFFF"
                }

                MouseArea {
                    id: loginHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: doLogin()
                }
            }

            Item { Layout.preferredHeight: 18 }

            // ── Session selector ──────────────────────────────────────────────
            Row {
                id: sessionRow
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                visible: sessionModel.rowCount() > 1

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "◀"
                    font { family: "Inter"; pixelSize: 11 }
                    color: Qt.rgba(1, 1, 1, 0.30)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sessionIdx = (sessionIdx - 1 + sessionModel.rowCount()) % sessionModel.rowCount();
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sessionModel.data(sessionModel.index(sessionIdx, 0), Qt.DisplayRole) || "Plasma"
                    font { family: "Inter"; pixelSize: 12 }
                    color: Qt.rgba(1, 1, 1, 0.40)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▶"
                    font { family: "Inter"; pixelSize: 11 }
                    color: Qt.rgba(1, 1, 1, 0.30)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sessionIdx = (sessionIdx + 1) % sessionModel.rowCount();
                        }
                    }
                }
            }
        }
    }

    // ── Error message ─────────────────────────────────────────────────────────
    Text {
        id: errMsg
        anchors { bottom: card.top; horizontalCenter: card.horizontalCenter; bottomMargin: 14 }
        text: ""
        font { family: "Inter"; pixelSize: 13 }
        color: "#FF5566"
        opacity: text !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // ── State ─────────────────────────────────────────────────────────────────
    property int sessionIdx: 0

    function doLogin() {
        errMsg.text = "";
        sddm.login(userField.text, passField.text, sessionIdx);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            passField.clear();
            passField.forceActiveFocus();
            errMsg.text = "Incorrect password — try again";
        }
    }

    Component.onCompleted: {
        // Pre-select the Plasma session if available
        for (var i = 0; i < sessionModel.rowCount(); i++) {
            var name = sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "";
            if (name.toLowerCase().indexOf("plasma") !== -1) {
                sessionIdx = i;
                break;
            }
        }
        userField.text !== "" ? passField.forceActiveFocus()
                              : userField.forceActiveFocus();
    }
}
