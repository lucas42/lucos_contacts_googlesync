FROM ruby:3-alpine

WORKDIR /usr/src/app

COPY . .

ENV PORT 8011
EXPOSE $PORT

CMD ["ruby", "server.rb"]
