@echo off

echo ==========================
echo   GitHub Upload Script
echo ==========================

set /p number=Enter upload number: 

echo.
echo Adding all files...
git add .

echo.
echo Committing...
git commit -m "upload %number%"

echo.
echo Pushing to GitHub...
git push

echo.
echo Done.
pause