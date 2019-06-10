FROM ruby:2-alpine

WORKDIR /usr/src/app

COPY . .

ENV PORT 8080
EXPOSE $PORT

CMD ["ruby", "server.rb"]
