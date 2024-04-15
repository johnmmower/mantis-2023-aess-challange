import pandas as pd
import numpy as np
from scipy.io import savemat, loadmat
import os

folder_path = "arctic_fox"
items = os.listdir(folder_path)
relative_paths = [os.path.join(folder_path, item) for item in items]

for path in relative_paths:
    df = pd.read_csv(path, index_col=0)

    # Extract the first two rows as strings
    string_data = df.iloc[:2]

    # Convert the rest of the DataFrame to complex numbers
    complex_data = df.iloc[2:].map(lambda x: complex(x.strip('()')) if isinstance(x, str) else x)

    data = {}

    for i, (col, values) in enumerate(string_data.items()):
        data[f'string_{i}'] = values.tolist()

    for col, values in complex_data.items():
        data[f'complex_{col}'] = [x for x in values]

    savemat('mats/' + path[:-3] + 'mat', data,)

print(loadmat('mats/' + path[:-3] + 'mat', data))
