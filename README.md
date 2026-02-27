# pocketpilot

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

## Developer Workflow

Because Android automatically disables Accessibility Services whenever an app is force-stopped or reinstalled, running standard `flutter run` will drop the background service privileges and require you to manually toggle them in the device settings on every rebuild.

To bypass this and **auto-enable Accessibility Services after every rebuild**, run this custom launch script in PowerShell instead:

```powershell
.\scripts\run_with_a11y.ps1
```
