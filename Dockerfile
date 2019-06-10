FROM ruby:2-alpine

WORKDIR /usr/src/app

COPY . .

CMD ["ruby", "server.rb", "8080", "services.l42.eu"]
