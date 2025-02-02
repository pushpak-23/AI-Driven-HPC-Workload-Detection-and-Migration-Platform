import pandas as pd
from prophet import Prophet

def predict_workload():
    # Load historical data
    df = pd.read_csv('/var/log/slurm_jobs.csv')
    model = Prophet()
    model.fit(df)
    forecast = model.make_future_dataframe(periods=24, freq='H')
    return forecast
