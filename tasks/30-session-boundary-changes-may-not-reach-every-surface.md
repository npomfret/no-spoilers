# Task 30: session boundary changes may not reach every surface

## The issue

Session start and effective-end decisions are shared, but the app, Home Screen widgets, alerts and
Live Activities each wake or refresh through a different platform mechanism. A boundary changing
while one of those surfaces is inactive may therefore leave that surface showing an older state
than the others.

One known example is an authoritative end time arriving before the estimated grace-window end:
the open app is invalidated, but the existing WidgetKit timeline is not explicitly reloaded. More
generally, changes to boundary timing or refresh behaviour could produce temporary disagreement
between surfaces even when they all use the same underlying session-status rules.
