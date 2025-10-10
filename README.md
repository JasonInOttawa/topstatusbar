# topstatusbar
KOReader patch to add a top status bar

This patch is based on the revised patch found in https://github.com/issues/mentioned?issue=joshuacant%7CKOReader.patches%7C1

<b>Changes from the Previous Patch</b>
1. Users can configure which items to show in each of the left/centre/right areas
2. The margins refresh if the display size changes (eg, resize window or orientation)
3. If "Hide battery item when higher than: XXX" is selected in Status Bar settings, then the battery icon and text is not displayed unless the current charge is under the selected threshold

<b>Future Changes</b>
1. Allow changes to the configuration by UI rather than file edits
2. Factor the code to remove the huge amounts of duplication
3. Add refresh to keep the clock / battery / wifi status up to date

<b>Refresh updates</b></br>
1. If "Auto refresh items" is selected in Status Bar settings, then the status bar is redrawn at the top of each minute</br>
2. If "Hide inactive items" is selected in Status Bar settings, then the wifi icon will only be displayed if wifi is turned on and connected<br>
