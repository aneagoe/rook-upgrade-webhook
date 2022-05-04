FROM python:3.10-alpine AS parent
WORKDIR /app
RUN pip3 install pipenv
COPY Pipfile* /app/

FROM parent AS intermediate
RUN pipenv install --deploy --system

FROM intermediate as app
COPY src /app
ENTRYPOINT ["gunicorn"]
CMD ["app:app"]
