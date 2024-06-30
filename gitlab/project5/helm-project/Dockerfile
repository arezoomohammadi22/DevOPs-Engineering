FROM python:3.9-slim

WORKDIR /app

COPY src/ .

RUN pip install flask

EXPOSE 80

CMD ["python", "main.py"]

