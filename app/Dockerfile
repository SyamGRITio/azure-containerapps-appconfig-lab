FROM golang:1.25-alpine AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY main.go .

RUN go build -o app main.go


FROM alpine:3.22

WORKDIR /app

COPY --from=builder /src/app /app/app

EXPOSE 8080

CMD ["/app/app"]