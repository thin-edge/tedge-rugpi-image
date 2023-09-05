docker run --rm --privileged ^
    -v .:/project ^
    -v /dev:/dev ^
    ghcr.io/silitics/rugpi-bakery:latest ^
    %*

if %errorlevel% neq 0 exit /b %errorlevel%
