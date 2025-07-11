
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

# Загрузка всех данных в DataFrame
def load_data():
    data = sheet.get_all_records()
    return pd.DataFrame(data)

# Обновление строки по ID и ключам из updates
def update_row_by_id(row_id, updates: dict):
    records = sheet.get_all_records()
    for i, row in enumerate(records, start=2):  # начиная с 2, так как 1-я строка — заголовки
        if str(row.get("id")) == str(row_id):
            for key, value in updates.items():
                if key in sheet.row_values(1):  # проверяем, что ключ существует
                    col = sheet.row_values(1).index(key) + 1
                    sheet.update_cell(i, col, value)
            return True
    return False

# Получить все слова
@app.route('/data', methods=['GET'])
def get_data():
    df = load_data()
    return df.to_json(orient="records")

# Обновить произвольные поля по ID
@app.route('/update', methods=['POST'])
def update_progress():
    content = request.json
    row_id = content.get("id")
    updates = content.get("updates", {})
    if not row_id or not updates:
        return jsonify({"error": "Missing 'id' or 'updates'"}), 400
    success = update_row_by_id(row_id, updates)
    return jsonify({"success": success})

# Получить случайное слово по прогрессу
@app.route('/data_by_progress', methods=['GET'])
def get_data_by_progress():
    try:
        progress = request.args.get("progress")
        if progress is None:
            return jsonify({"error": "Missing 'progress' parameter"}), 400
        df = load_data()
        filtered = df[df["progress"] == int(progress)]
        sample = filtered.sample(1) if not filtered.empty else pd.DataFrame()
        return sample.to_json(orient="records")
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Обновить used_correctly
@app.route('/update_usage', methods=['POST'])
def update_usage():
    content = request.json
    row_id = content.get("id")
    used_correctly = content.get("used_correctly")

    if row_id is None:
        return jsonify({"error": "Missing 'id'"}), 400

    if used_correctly != "":
        try:
            used_correctly = int(used_correctly)
        except ValueError:
            return jsonify({"error": "'used_correctly' must be an integer or empty string"}), 400

    success = update_row_by_id(row_id, {"used_correctly": used_correctly})
    return jsonify({"success": success})

# Запуск сервера
if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)

