#!/usr/bin/env python3

import sys
import numpy as np
import statsmodels.api as sm
import math

"""
Linear regression calculation. Nothing original here, see
https://realpython.com/linear-regression-in-python/#advanced-linear-regression-with-statsmodels
for details.

An example of running this script on the output of npgqc_dbix_schema_loader.pl
cat some_data.tsv | grep -v id_run | cut -d$'\t' -f6,7 | ./simple_stats.py
"""

num_reads = []
num_reads_norm = []
for line in sys.stdin:
    line = line.rstrip()
    (nr, nrn) = line.split("\t");
    num_reads.append(float(nr))
    num_reads_norm.append(float(nrn))

x = np.array(num_reads).reshape((-1, 1))
y = np.array(num_reads_norm)

x = sm.add_constant(x)
model = sm.OLS(y, x)
results = model.fit()
print(results.summary())

(intercept, slope) = results.params
p_100 = intercept + slope*2
bt_100 = math.pow(10, p_100)
print(f'Prediction for 100 {p_100}, back-transform {bt_100}')
p_1000 = intercept + slope*3
bt_1000 = math.pow(10, p_1000)
print(f'Prediction for 1000 {p_1000} back-transform {bt_1000}')

