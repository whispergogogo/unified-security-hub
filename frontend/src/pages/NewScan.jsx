import { useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { createSASTJob, createPentestJob, uploadZip, startScan } from '../api/client'
import { Upload, Link, CheckCircle, AlertCircle, Loader2 } from 'lucide-react'

export default function NewScan() {
  const [tab, setTab] = useState('sast')
  return (
    <div className="max-w-xl">
      {/* Tab switcher */}
      <div className="flex bg-gray-100 rounded-lg p-1 mb-6 w-fit">
        {['sast', 'pentest'].map(t => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`px-5 py-1.5 rounded-md text-sm font-medium transition-all ${
              tab === t
                ? 'bg-white shadow-sm text-gray-900'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            {t === 'sast' ? 'SAST' : 'Pentest'}
          </button>
        ))}
      </div>

      {tab === 'sast' ? <SASTForm /> : <PentestForm />}
    </div>
  )
}

// ── SAST Form ─────────────────────────────────────────────────────────────────
function SASTForm() {
  const [file, setFile]         = useState(null)
  const [step, setStep]         = useState('idle') // idle | uploading | scanning | done | error
  const [findingId, setFindingId] = useState(null)
  const [error, setError]       = useState(null)
  const inputRef                = useRef()
  const navigate                = useNavigate()

  const handleFile = (f) => {
    if (!f) return
    if (!f.name.endsWith('.zip')) {
      setError('Only .zip files are supported.')
      return
    }
    setFile(f)
    setError(null)
  }

  const handleDrop = (e) => {
    e.preventDefault()
    handleFile(e.dataTransfer.files[0])
  }

  const handleSubmit = async () => {
    if (!file) { setError('Please select a .zip file.'); return }
    setError(null)

    try {
      // 1. Create job → get pre-signed URL
      setStep('uploading')
      const { findingId: id, uploadUrl } = await createSASTJob()
      setFindingId(id)

      // 2. Upload zip to S3
      await uploadZip(uploadUrl, file)

      // 3. Start scan
      setStep('scanning')
      await startScan(id)

      setStep('done')
    } catch (e) {
      setError(e.message)
      setStep('error')
    }
  }

  if (step === 'done') {
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-8 text-center shadow-sm">
        <CheckCircle className="mx-auto text-green-500 mb-3" size={40} />
        <h3 className="text-base font-semibold text-gray-800 mb-1">Scan started!</h3>
        <p className="text-sm text-gray-500 mb-5">
          Job <span className="font-mono">{findingId?.slice(0, 8)}...</span> is now running.
        </p>
        <button
          onClick={() => navigate('/dashboard')}
          className="text-sm bg-blue-600 text-white px-5 py-2 rounded-lg hover:bg-blue-700 transition-colors"
        >
          View Dashboard
        </button>
      </div>
    )
  }

  return (
    <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-6 space-y-5">
      <div>
        <h2 className="text-sm font-semibold text-gray-800 mb-1">Static Code Analysis (SAST)</h2>
        <p className="text-xs text-gray-500">Upload a .zip of your JavaScript source code to scan for vulnerabilities.</p>
      </div>

      {/* Dropzone */}
      <div
        onDrop={handleDrop}
        onDragOver={e => e.preventDefault()}
        onClick={() => inputRef.current?.click()}
        className={`border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors ${
          file ? 'border-blue-300 bg-blue-50' : 'border-gray-200 hover:border-blue-300 hover:bg-gray-50'
        }`}
      >
        <input
          ref={inputRef}
          type="file"
          accept=".zip"
          className="hidden"
          onChange={e => handleFile(e.target.files[0])}
        />
        <Upload className={`mx-auto mb-2 ${file ? 'text-blue-500' : 'text-gray-400'}`} size={28} />
        {file ? (
          <p className="text-sm font-medium text-blue-700">{file.name}</p>
        ) : (
          <>
            <p className="text-sm text-gray-600">Drop your .zip file here, or <span className="text-blue-600">browse</span></p>
            <p className="text-xs text-gray-400 mt-1">Only .zip files supported</p>
          </>
        )}
      </div>

      {error && (
        <div className="flex items-center gap-2 text-sm text-red-600 bg-red-50 px-3 py-2 rounded-lg">
          <AlertCircle size={15} />
          {error}
        </div>
      )}

      <StepIndicator step={step} />

      <button
        onClick={handleSubmit}
        disabled={step === 'uploading' || step === 'scanning'}
        className="w-full flex items-center justify-center gap-2 bg-blue-600 text-white text-sm font-medium py-2.5 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        {(step === 'uploading' || step === 'scanning') && <Loader2 size={15} className="animate-spin" />}
        {step === 'uploading' ? 'Uploading...' : step === 'scanning' ? 'Starting scan...' : 'Start Scan'}
      </button>
    </div>
  )
}

// ── Pentest Form ──────────────────────────────────────────────────────────────
function PentestForm() {
  const [url, setUrl]           = useState('')
  const [step, setStep]         = useState('idle')
  const [findingId, setFindingId] = useState(null)
  const [error, setError]       = useState(null)
  const navigate                = useNavigate()

  const handleSubmit = async () => {
    if (!url.trim()) { setError('Please enter a target URL.'); return }
    if (!url.startsWith('http')) { setError('URL must start with http:// or https://'); return }
    setError(null)

    try {
      setStep('creating')
      const { findingId: id } = await createPentestJob(url)
      setFindingId(id)

      setStep('scanning')
      await startScan(id)

      setStep('done')
    } catch (e) {
      setError(e.message)
      setStep('error')
    }
  }

  if (step === 'done') {
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-8 text-center shadow-sm">
        <CheckCircle className="mx-auto text-green-500 mb-3" size={40} />
        <h3 className="text-base font-semibold text-gray-800 mb-1">Pentest started!</h3>
        <p className="text-sm text-gray-500 mb-5">
          Job <span className="font-mono">{findingId?.slice(0, 8)}...</span> is running against <span className="text-gray-700">{url}</span>
        </p>
        <button
          onClick={() => navigate('/dashboard')}
          className="text-sm bg-blue-600 text-white px-5 py-2 rounded-lg hover:bg-blue-700 transition-colors"
        >
          View Dashboard
        </button>
      </div>
    )
  }

  return (
    <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-6 space-y-5">
      <div>
        <h2 className="text-sm font-semibold text-gray-800 mb-1">API Penetration Testing</h2>
        <p className="text-xs text-gray-500">Enter the URL of the API you want to test for security vulnerabilities.</p>
      </div>

      <div className="space-y-1">
        <label className="text-xs font-medium text-gray-700">Target URL</label>
        <div className="flex items-center gap-2 border border-gray-200 rounded-lg px-3 py-2 focus-within:border-blue-400 focus-within:ring-2 focus-within:ring-blue-100">
          <Link size={15} className="text-gray-400 flex-shrink-0" />
          <input
            type="url"
            value={url}
            onChange={e => { setUrl(e.target.value); setError(null) }}
            placeholder="https://example.com or http://ip:4000"
            className="flex-1 text-sm outline-none bg-transparent text-gray-800 placeholder-gray-400"
          />
        </div>
      </div>

      {/* Quick fill buttons */}
      <div className="flex gap-2">
        <span className="text-xs text-gray-400 self-center">Quick fill:</span>
        <button
          onClick={() => setUrl('https://restful-api.dev')}
          className="text-xs text-blue-600 hover:underline"
        >
          restful-api.dev
        </button>
      </div>

      {/* Test-target instructions */}
      <div className="bg-amber-50 border border-amber-200 rounded-lg px-4 py-3 space-y-1.5">
        <p className="text-xs font-semibold text-amber-800">Using Test Target?</p>
        <p className="text-xs text-amber-700">
            The test-target is a deliberately vulnerable API running as a persistent ECS Service — no manual start needed. Just retrieve its public IP and paste it here.
        </p>
        <ol className="text-xs text-amber-700 list-decimal list-inside space-y-0.5">
            <li>Get the public IP via AWS CLI (see <code className="bg-amber-100 px-1 rounded">frontend-testing.md</code>)</li>
            <li>Enter <code className="bg-amber-100 px-1 rounded">http://&lt;public-ip&gt;:4000</code> above</li>
        </ol>
      </div>

      {error && (
        <div className="flex items-center gap-2 text-sm text-red-600 bg-red-50 px-3 py-2 rounded-lg">
          <AlertCircle size={15} />
          {error}
        </div>
      )}

      <StepIndicator step={step} pentest />

      <button
        onClick={handleSubmit}
        disabled={step === 'creating' || step === 'scanning'}
        className="w-full flex items-center justify-center gap-2 bg-teal-600 text-white text-sm font-medium py-2.5 rounded-lg hover:bg-teal-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        {(step === 'creating' || step === 'scanning') && <Loader2 size={15} className="animate-spin" />}
        {step === 'creating' ? 'Creating job...' : step === 'scanning' ? 'Starting scan...' : 'Start Pentest'}
      </button>
    </div>
  )
}

// ── Step indicator ────────────────────────────────────────────────────────────
function StepIndicator({ step, pentest = false }) {
  const steps = pentest
    ? ['Create job', 'Start scan']
    : ['Create job', 'Upload zip', 'Start scan']

  const activeIdx = {
    idle: -1,
    creating: 0,
    uploading: 0,
    scanning: pentest ? 1 : 2,
    done: steps.length,
    error: -1,
  }[step] ?? -1

  if (step === 'idle' || step === 'error') return null

  return (
    <div className="flex items-center gap-1">
      {steps.map((s, i) => (
        <div key={s} className="flex items-center gap-1">
          <div className={`flex items-center gap-1.5 text-xs px-2 py-1 rounded-full ${
            i < activeIdx
              ? 'bg-green-100 text-green-700'
              : i === activeIdx
              ? 'bg-blue-100 text-blue-700'
              : 'bg-gray-100 text-gray-400'
          }`}>
            {i < activeIdx
              ? <CheckCircle size={11} />
              : i === activeIdx
              ? <Loader2 size={11} className="animate-spin" />
              : null
            }
            {s}
          </div>
          {i < steps.length - 1 && <span className="text-gray-300">›</span>}
        </div>
      ))}
    </div>
  )
}