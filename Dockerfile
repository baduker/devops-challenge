FROM python:3.10-slim

RUN addgroup --system sherpany && adduser --system --ingroup sherpany sherpany

WORKDIR /app

RUN apt-get update && apt-get install -y \
    libpq-dev gcc && \
    rm -rf /var/lib/apt/lists/*

COPY ./source/requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY ./source/app.py app.py

RUN chown -R sherpany:sherpany /app

USER sherpany

EXPOSE 8080

ENV FLASK_APP=app.py

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--log-level", "info", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
