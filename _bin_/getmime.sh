#!/bin/bash

file -i $1 | cut -d " " -f 2 | cut -d ";" -f 1 
