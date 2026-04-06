@echo off
cd /d "C:\Dev\godot-projects\mvp-04\"
git add -A
git commit -m "auto-sync %date% %time%"
git push
git pull
