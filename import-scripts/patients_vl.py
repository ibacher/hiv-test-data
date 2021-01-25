#!/usr/bin/env python
# coding: utf-8

import numpy as np
import requests

patients = np.genfromtxt('data/patients.csv', delimiter=',', dtype=None, encoding=None, skip_header=1)
vl_obs = np.genfromtxt('data/vl_obs.csv', delimiter=',', dtype=None, encoding=None, skip_header=1)


# SAVE PERSON OBJECT
def savePerson(p):
    person = {
        "names": [
            {
                "givenName": "",
                "familyName": ""
            }
        ],
        "gender": "",
        "birthdate": ""
    }

    person['names'][0]['givenName'] = p[1]
    person['names'][0]['familyName'] = p[2]
    person['gender'] = p[3]
    person['birthdate'] = p[4]

    try:
        r = requests.post(
            "https://openmrs-spa.org/openmrs/ws/rest/v1/person",
            json=person,
            auth=('admin', 'Admin123'),
        )
        r.raise_for_status()
        print('PERSON SAVED SUCCESSFULLY')
        return r.json()
    except requests.exceptions.HTTPError as err:
        raise SystemExit(err)


# SAVE PATIENT OBJECT
def savePatient(r):
    patient = {
        "person": r['uuid'],
        "identifiers": [
            {
                "identifier": p[0],
                "identifierType": "05a29f94-c0ed-11e2-94be-8c13b969e334",
                "location": "58c57d25-8d39-41ab-8422-108a0c277d98",
                "preferred": True
            }
        ]
    }

    try:
        r = requests.post(
            "https://openmrs-spa.org/openmrs/ws/rest/v1/patient",
            json=patient,
            auth=('admin', 'Admin123'),
        )
        r.raise_for_status()
        print('PATIENT SAVED SUCCESSFULLY')
        return r.json()
    except requests.exceptions.HTTPError as err:
        raise SystemExit(err)


# SAVE ENCOUNTER OBJECT
def savePatientEncounter(patient):
    current_patient_obs = []
    for obs in vl_obs:
        if obs[0] == p[0]:
            current_patient_obs.append(obs)

    # Construct encounter payload
    obs = {
        "patient": patient['uuid'],
        "encounterDatetime": vl_obs[0][1],
        "location": "58c57d25-8d39-41ab-8422-108a0c277d98",
        "encounterType": "d7151f82-c1f3-4152-a605-2f9ea7414a79",
        "obs": []
    }

    for v in current_patient_obs:
        obs['obs'].append({
            'concept': '856AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
            'value': int(v[2]),
            'obsDatetime': v[1],
        })

    try:
        obs_res = requests.post(
            "https://openmrs-spa.org/openmrs/ws/rest/v1/encounter",
            json=obs,
            auth=('admin', 'Admin123'),
        )
        obs_res.raise_for_status()
        print('ENCOUNTER SAVED SUCCESSFULLY')
        return obs_res.json()
    except requests.exceptions.HTTPError as err:
        raise SystemExit(err)


for p in patients:
    savePatientEncounter(savePatient(savePerson(p)))
