#!/bin/bash
FILE=/usr/bin/python
if [ -f "$FILE" ]; then
    echo "$FILE exists."
else
    echo "$FILE does not exist hence creating soft link"
    ln -s /usr/bin/python3 $FILE
fi
