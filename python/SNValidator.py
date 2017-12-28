#!/usr/bin/env python3
# coding=utf-8
import sys
import SNWorker

def main():
    parmLen = len(sys.argv)
    if(parmLen>1):
        for index in range(len(sys.argv)):
            if(index!=0):
                currentSN = str(sys.argv[index]);
                print('GOT:' + currentSN)
                snw = SNWorker.SNWorker(index,'W'+str(index), currentSN);
                snw.start();
    else:
        print("Parameter missing, please pass SN")

#CALL
main()