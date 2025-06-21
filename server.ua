from flask import Flask, request, jsonify
import pandas as pd
import datetime
import os
import gspread
from google.oauth2.service_account import Credentials

app = Flask(__name__)

# Авторизация через Google Sheets API
scope = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]
creds = Credentials.from_service_account_file("/etc/secrets/credentials.json", scopes=scope)
client = gspread.authorize(creds)

# Открытие таблицы по ID
SHEET_ID = "1H2EHXGZ5uHs9tsvD6eoBibaMLbZ37COhsewiKerDJZo"
sheet = client.open_by_key(SHEET_ID).sheet1

# Загрузка данных в DataFrame
def load_data():
    data = sheet.get_all_records()
    return pd.DataFrame(data)

# Обновление ячеек по ID
def update_row_by_id(row_id, updates: dict):
    df = load_data()
    idx_list = df.index[df["ID"] == row_id].tolist()
    if not idx_list:
        return False
    row_index = idx_list[0] + 2
    for col, val in updates.items():
        col_index = df.columns.get_loc(col) + 1
        sheet.update_cell(row_index, col_index, val)
    return True

# Фильтрация по 1-N параметрам
def filter_data(filters: dict):
    df = load_data()
    for col, val in filters.items():
        df = df[df[col] == val]
    return df.to_dict(orient="records")

@app.route("/")
def home():
    return "Vocabulary API is running!"

@app.route("/get", methods=["POST"])
def get_filtered():
    filters = request.json
    return jsonify(filter_data(filters))

@app.route("/update", methods=["POST"])
def update():
    data = request.json
    word_id = data.pop("ID", None)
    if not word_id:
        return jsonify({"error": "Missing ID"}), 400
    success = update_row_by_id(word_id, data)
    return jsonify({"success": success})
