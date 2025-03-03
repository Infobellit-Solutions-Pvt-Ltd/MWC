import os
import json
import sys
from datetime import datetime

import pandas as pd
import pika
from flask import Flask, request

# Notes
# This script is a flask application that catches data pushed out
# from Raritan PX-3 & PX-4 ePDUs, deconstruct the file, and
# drop all the information other than Watts and Watt-Hours,
# and drop rows that are reporting 0.0000, then reformat as
# json.

# notes for the using
# the ePDU being used for development is located at: https://10.86.22.121/#/signin

# Bangalore Lab Setup
# 3 ePUD's
# Machine 1P
# 10.86.27.111 - Serial Number: 2HM3200064
# Outlet 22 - Outlet Group 11
# Machine 2PC_A
# 10.86.22.121 - Serial Number: 2HM3200030
# Outlet 1 - Outlet Group 1
# Machine 2P
# 10.86.18.200 - Serial Number: RF43300051
# Outlet 31 - Outlet Group 16
# Machine 2P
# 10.86.18.200 - Serial Number: RF43300051
# Outlet 30 - Outlet Group 15

# Spain Demo Setup
# 2 ePDUs
# Machine 1P
# Serial Number = epdu1
# outletGrp = 1
# Machine 2P
# Serial Number = epdu1
# outletGrp = 2
# Machine 2PC_A
# Serial Number = epdu2
# outletGrp = 1
# Machine 2PC_B
# Serial Number = epdu2
# outletGrp = 2

###########################################################################################
# read inputs from file
if len(sys.argv) != 2:
    print('Usage: Python catcherDemo_0.9.py <input_file.text>')
    sys.exit(1)

input_file = sys.argv[1]
input_params = {}
try:
    with open(input_file, 'r') as file:
        for line in file:
            line = line.strip()
            if line:
                if '=' in line:
                    key, value = line.split('=', 1)
                    input_params[key.strip()] = value.strip()
                else:
                    print(f"Invalid line in format: '{line}'")
                    sys.exit(1)
except FileNotFoundError:
    print(f"Error: The file '{input_file}' does not exist.")
    sys.exit(1)


location = input_params.get('location')

if location == 'bangalore':
    print('Launching with Bangalore settings...')

elif location == 'spain':
    epdu1 = input_params.get('epdu1')
    epdu2 = input_params.get('epdu2')
    if epdu1 and epdu2:
        print('Launching with Spain settings...')
        print(f'ePDU1 Serial Number: {epdu1}')
        print(f'ePDU2 Serial Number: {epdu2}')
    else:
        print('Error: Missing ePDU1 or ePDU2 in input file for Spain')
        sys.exit(1)
else:
    print("Error: Invalid or missing location in Input file.")
    sys.exit(1)

###########################################################################################
# RabbitMQ Push

print(os.getenv('RABBITMQ_HOST'))
RABBITMQ_HOST = os.getenv('RABBITMQ_HOST')
RABBITMQ_USER = 'admin'
RABBITMQ_PASSWORD = 'Infobell1234#'

CREDENTIALS = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
CONNECTION_PARAMS = pika.ConnectionParameters(host=RABBITMQ_HOST, credentials=CREDENTIALS)


def send_to_rabbitmq(queue_name, data):
    try:
        if queue_name == '2PC_POWER_A' or queue_name == '2PC_POWER_B':
            data['watts'] = data['watts'] * 1.15

        connection = pika.BlockingConnection(CONNECTION_PARAMS)
        channel = connection.channel()
        channel.queue_declare(queue=queue_name, durable=True)
        channel.basic_publish(exchange='', routing_key=queue_name, body=json.dumps(data))

        connection.close()
    except Exception as e:
        with open("power-data-push.log", "a") as f:
            print(f"Error sending data to RabbitMQ: {e}", file=f)


def cleaner(data):
    corpus = data
    sensors = corpus['sensors']

    pivFrames = []
    for row in corpus['rows']:
        try:
            sensorsDF = pd.DataFrame(sensors)
            sensorsDF = pd.concat([sensorsDF.drop(['device'], axis=1), sensorsDF['device'].apply(pd.Series)], axis=1)
            df_read = pd.DataFrame(row['records'])
            sensorsDF = sensorsDF.join(df_read)
            sensorsDF = sensorsDF[sensorsDF['type'] == 4]
            piv = pd.pivot_table(sensorsDF, values='avgValue', index=['label', 'name'], columns='id')
            piv = piv.reset_index()
            piv = piv[['label', 'name', 'activeEnergy', 'activePower']]
            piv.insert(loc=1, column='outletDesignation', value=piv['label'] + "-" + corpus['serialNumber'])
            piv.insert(loc=2, column='serialNum', value=corpus['serialNumber'])
            piv.insert(0, 'tStampEpoch', row['timestamp'])
            rts = str(datetime.fromtimestamp(row['timestamp']))
            piv.insert(0, 'tStamp', rts)
            piv = piv.rename(columns={'label': 'outletNo', 'name': 'chassisServiced', 'activeEnergy': 'energyWH', 'activePower': 'powerWatts'})
            pivTot = pd.DataFrame(piv)
            pivFrames.append(pivTot)

        except Exception as e:
            print(str(e))

    comboPivFrames = pd.concat(pivFrames, axis=0, ignore_index=True)

    avgPowerWatts = comboPivFrames.groupby('outletNo').agg(
        serialNum=('serialNum', 'first'),
        avgPowerWatts=('powerWatts', 'mean'),
        minPowerWatts=('powerWatts', 'min'),
        maxPowerWatts=('powerWatts', 'max'),
        minTimestamp=('tStamp', 'min'),
        maxTimestamp=('tStamp', 'max')
    ).reset_index()

    avgPowerWatts['outletNo'] = avgPowerWatts['outletNo'].astype(int)
    avgPowerWatts['outletGrp'] = (avgPowerWatts['outletNo'] - 1) // 2 + 1
    coupledOutletSums = avgPowerWatts.groupby('outletGrp').agg(
        avgPowerWatts=('avgPowerWatts', 'sum'),
        serialNum=('serialNum', 'first'),
        minTimestamp=('minTimestamp', 'first'),
        maxTimestamp=('maxTimestamp', 'first')
    ).reset_index()

    if location == '1' or location == 'bangalore':
        print('Bangalore')
        if coupledOutletSums.loc[0, 'serialNum'] == '2HM3200064':
            machine = '1P'
            watts = float(coupledOutletSums.loc[coupledOutletSums['outletGrp'] == 11, 'avgPowerWatts'].values[0])

            # Machine 1P
            print('Machine: ', machine, 'Watts: ', watts)
            send_to_rabbitmq("1P_POWER", {'watts': watts})
            print('*****************************')

        elif coupledOutletSums.loc[0, 'serialNum'] == '2HM3200030':
            machine = '2PC_A'
            watts = float(coupledOutletSums.loc[coupledOutletSums['outletGrp'] == 1, 'avgPowerWatts'].values[0])

            # Machine 2PC_A
            print('Machine:', machine, 'Watts: ', watts)
            send_to_rabbitmq("2PC_POWER_A", {'watts': watts})
            print('*****************************')

        elif coupledOutletSums.loc[0, 'serialNum'] == 'RF43300051':
            machine1 = '2P'
            machine2 = '2PC_B'
            idx1 = coupledOutletSums[coupledOutletSums['outletGrp'] == 16].index[0]
            idx2 = coupledOutletSums[coupledOutletSums['outletGrp'] == 15].index[0]
            watts1 = float(coupledOutletSums.loc[idx1, 'avgPowerWatts'])
            watts2 = float(coupledOutletSums.loc[idx2, 'avgPowerWatts'])

            # Machine 2P
            print('Machine:', machine1, 'Watts: ', watts1)
            send_to_rabbitmq("2P_POWER", {"watts": watts1})
            print('*****************************')

            # Machine 2PC_B
            print('Machine:', machine2, 'Watts: ', watts2)
            send_to_rabbitmq("2PC_POWER_B", {"watts": watts2})
            print('*****************************')

    elif location == '2' or location == 'spain':
        print('Spain')
        if coupledOutletSums.loc[0, 'serialNum'] == epdu1:
            machine1 = '1P'
            machine2 = '2P'
            idx1 = coupledOutletSums[coupledOutletSums['outletGrp'] == 1].index[0]
            idx2 = coupledOutletSums[coupledOutletSums['outletGrp'] == 2].index[0]
            watts1 = float(coupledOutletSums.loc[idx1, 'avgPowerWatts'])
            watts2 = float(coupledOutletSums.loc[idx2, 'avgPowerWatts'])

            # Machine 1P
            print('Machine:', machine1, 'Watts: ', watts1)
            send_to_rabbitmq("1P_POWER", {"watts": watts1})
            print('*****************************')

            # Machine 2P
            print('Machine:', machine2, 'Watts: ', watts2)
            send_to_rabbitmq("2P_POWER", {"watts": watts2})
            print('*****************************')
        elif coupledOutletSums.loc[0, 'serialNum'] == epdu2:
            machine1 = '2PC_A'
            machine2 = '2PC_B'
            idx1 = coupledOutletSums[coupledOutletSums['outletGrp'] == 1].index[0]
            idx2 = coupledOutletSums[coupledOutletSums['outletGrp'] == 2].index[0]
            watts1 = float(coupledOutletSums.loc[idx1, 'avgPowerWatts'])
            watts2 = float(coupledOutletSums.loc[idx2, 'avgPowerWatts'])

            # Machine 2PC_A
            print('Machine:', machine1, 'Watts: ', watts1)
            send_to_rabbitmq("2PC_POWER_A", {"watts": watts1})
            print('*****************************')

            # Machine 2PC_B
            print('Machine:', machine2, 'Watts: ', watts2)
            send_to_rabbitmq("2PC_POWER_B", {"watts": watts2})
            print('*****************************')

    else:
        print('No Valid Location, something went wrong, etc.')


app = Flask(__name__)


@app.route('/catch', methods=['POST'])
def catch():
    data = request.get_json()
    cleaner(data)
    return '<h1> Welcome </h1>'


app.run(host="0.0.0.0")
