@echo off
REM Build a lean review zip (source/docs/data only) of this project for upload/review.
REM Double-click this file, or run it from a terminal. The zip lands one folder UP from
REM the project, timestamped. Edit make_review_zip.ps1 to change the filter rules.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_review_zip.ps1"
echo.
pause
