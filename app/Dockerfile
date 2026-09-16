FROM golang:1.25-alpine AS builder
WORKDIR /src

COPY main.go .
RUN go build -o app main.go

FROM alpine:3.22
WORKDIR /app

COPY --from=builder /src/app /app/app

EXPOSE 8080

CMD [ "/app/app" ]