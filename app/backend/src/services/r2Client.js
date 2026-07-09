'use strict';

const { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const env = require('../config/env');
const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');

let _client = null;

function getClient() {
  if (_client) return _client;
  const { accountId, accessKeyId, secretAccessKey } = env.r2;
  if (!accountId || !accessKeyId || !secretAccessKey) {
    throw ApiError.upstream('Cloudflare R2 not configured.');
  }
  _client = new S3Client({
    region: env.r2.region,
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    credentials: { accessKeyId, secretAccessKey },
  });
  return _client;
}

function buildKey(userId, originalName) {
  const safe = (originalName || 'file').replace(/[^A-Za-z0-9._-]/g, '_');
  const ts = Date.now();
  const rand = Math.random().toString(36).slice(2, 8);
  return `users/${userId}/${ts}-${rand}-${safe}`;
}

function publicUrl(key) {
  if (env.r2.publicBaseUrl) {
    return `${env.r2.publicBaseUrl.replace(/\/$/, '')}/${encodeURI(key)}`;
  }
  return null;
}

async function presignUpload(userId, { filename, contentType = 'image/jpeg' }) {
  const key = buildKey(userId, filename);
  const command = new PutObjectCommand({
    Bucket: env.r2.bucket,
    Key: key,
    ContentType: contentType,
  });
  const url = await getSignedUrl(getClient(), command, { expiresIn: env.r2.presignExpires });
  return {
    uploadUrl: url,
    method: 'PUT',
    headers: { 'Content-Type': contentType },
    key,
    publicUrl: publicUrl(key),
    expiresIn: env.r2.presignExpires,
  };
}

async function uploadBuffer(userId, buffer, { filename, contentType = 'image/jpeg' }) {
  const key = buildKey(userId, filename);
  await getClient().send(
    new PutObjectCommand({
      Bucket: env.r2.bucket,
      Key: key,
      Body: buffer,
      ContentType: contentType,
    })
  );
  return { key, publicUrl: publicUrl(key) };
}

async function presignDownload(key) {
  const command = new GetObjectCommand({ Bucket: env.r2.bucket, Key: key });
  const url = await getSignedUrl(getClient(), command, { expiresIn: env.r2.presignExpires });
  return { url, expiresIn: env.r2.presignExpires };
}

async function deleteFile(key) {
  try {
    await getClient().send(
      new DeleteObjectCommand({
        Bucket: env.r2.bucket,
        Key: key,
      })
    );
    logger.info({ key }, 'Deleted file from R2 bucket');
    return true;
  } catch (err) {
    logger.warn({ err: err.message, key }, 'Failed to delete file from R2 bucket');
    return false;
  }
}

function isConfigured() {
  return Boolean(env.r2.accountId && env.r2.accessKeyId && env.r2.secretAccessKey);
}

module.exports = { presignUpload, uploadBuffer, presignDownload, isConfigured, publicUrl, deleteFile };

void logger; // silence unused-import lint, kept for future debug logs
