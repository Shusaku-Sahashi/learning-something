# これは「よくある初期状態」のDockerfileです。動きはしますが、実務では避けたい書き方が
# 複数含まれています。01-dockerfile-quality/README.md の手順に沿って、このファイルを
# 自分の手で改善していってください。

FROM python:3.12
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
ENV REDIS_HOST=redis
EXPOSE 8000
CMD ["python", "app.py"]
