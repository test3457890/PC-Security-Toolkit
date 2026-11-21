# Scan-only preview gallery

These screens were captured by the [hosted Chromium screenshot check](../../../.github/workflows/preview-screenshots.yml)
from the actual preview page on November 20, 2026. The CI test opens the
local Python server and checks consent and rendered results. The sample-results
request uses a small fixture with unknown control values. A banner in those images
says CI TEST FIXTURE. The screenshots do not show a scan of the owner’s computer
or prove Windows launcher, elevated, USB, or recovery behavior.

## Consent screen

![Consent screen](01%20Consent%20screen.webp)

## Labeled sample results

![Sample results](02%20Sample%20results.webp)

## Mobile light theme

![Mobile light theme](03%20Mobile%20light%20theme.webp)

The source capture is [Tests/capture_preview.cjs](../../../Tests/capture_preview.cjs).
Use the [Windows testing checklist](../../Windows%20Testing%20Checklist.md)
for device-specific acceptance. The [legacy gallery](../README.md) contains
SIMULATED v3.1 examples from the old dashboard.
