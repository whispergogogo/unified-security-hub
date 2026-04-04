import { mockJobs, mockReport } from '../mock/data'

const USE_MOCK = import.meta.env.VITE_USE_MOCK === 'true'
const API_URL  = import.meta.env.VITE_API_URL
const API_KEY  = import.meta.env.VITE_API_KEY

const headers = () => ({
  'Content-Type': 'application/json',
  'x-api-key': API_KEY,
})

// ── List all jobs ────────────────────────────────────────────────────────────
export const listJobs = async () => {
  if (USE_MOCK) return { jobs: mockJobs }
  const res = await fetch(API_URL, { headers: headers() })
  return res.json()
}

// ── Get single job ───────────────────────────────────────────────────────────
export const getJob = async (findingId) => {
  if (USE_MOCK) return mockJobs.find(j => j.findingId === findingId) || mockJobs[0]
  const res = await fetch(`${API_URL}/${findingId}`, { headers: headers() })
  return res.json()
}

// ── Create SAST job → returns { findingId, uploadUrl } ──────────────────────
export const createSASTJob = async (userId = 'default-user') => {
  if (USE_MOCK) return { findingId: 'mock-new-123', uploadUrl: null, status: 'PENDING' }
  const res = await fetch(API_URL, {
    method: 'POST',
    headers: headers(),
    body: JSON.stringify({ scanType: 'SAST', userId }),
  })
  return res.json()
}

// ── Create Pentest job ───────────────────────────────────────────────────────
export const createPentestJob = async (targetUrl, userId = 'default-user') => {
  if (USE_MOCK) return { findingId: 'mock-new-456', status: 'PENDING' }
  const res = await fetch(API_URL, {
    method: 'POST',
    headers: headers(),
    body: JSON.stringify({ scanType: 'PENTEST', targetUrl, userId }),
  })
  return res.json()
}

// ── Upload zip to S3 pre-signed URL ─────────────────────────────────────────
export const uploadZip = async (uploadUrl, file) => {
  if (USE_MOCK) return
  await fetch(uploadUrl, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/zip' },
    body: file,
  })
}

// ── Start scan ───────────────────────────────────────────────────────────────
export const startScan = async (findingId) => {
  if (USE_MOCK) return { findingId, status: 'RUNNING' }
  const res = await fetch(`${API_URL}/${findingId}/start`, {
    method: 'POST',
    headers: headers(),
  })
  return res.json()
}

// ── Get report from S3 ───────────────────────────────────────────────────────
export const getReport = async (findingId) => {
  if (USE_MOCK) return mockReport
  const res = await fetch(`${API_URL}/${findingId}/report`, { headers: headers() })
  if (!res.ok) return null
  return res.json()
}