FROM node:18-alpine

# unzip is required to extract the source zip downloaded from S3
RUN apk add --no-cache unzip

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --production

COPY . .

# One-shot task — exits when scan is complete
CMD ["node", "index.js"]