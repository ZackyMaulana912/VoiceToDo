import { useState } from 'react'
import type { Category, Rec, RecStatus, Todo } from '../data'

const asset = (name: string) => `/assets/${name}.svg`

export const Icon = ({ name, size = 24, className = '' }: { name: string; size?: number; className?: string }) => (
  <img src={asset(name)} width={size} height={size} alt="" className={`block shrink-0 ${className}`} />
)

const catStyle: Record<Category, string> = {
  Rapat: 'bg-[#eef2ff] text-[#4338ca]',
  Kuliah: 'bg-[#f0fdfa] text-[#0f766e]',
  Ide: 'bg-[#fffbeb] text-[#92400e]',
}
const statusStyle: Record<RecStatus, string> = {
  selesai: 'bg-[#f0fdf4] text-[#166534]',
  memproses: 'bg-[#fffbeb] text-[#92400e]',
  gagal: 'bg-[#fef2f2] text-[#b91c1c]',
}
const statusLabel: Record<RecStatus, string> = { selesai: 'Selesai', memproses: 'Memproses', gagal: 'Gagal' }

const chipBase = 'inline-flex h-[26px] items-center rounded-full px-3 text-[13px] font-medium leading-[18px] whitespace-nowrap'

export const CategoryChip = ({ cat }: { cat: Category }) => <span className={`${chipBase} ${catStyle[cat]}`}>{cat}</span>
export const DueChip = ({ label }: { label: string }) => <span className={`${chipBase} bg-[#f1f5f9] text-[#475569]`}>{label}</span>
export const StatusChip = ({ status }: { status: RecStatus }) => (
  <span className={`${chipBase} ${statusStyle[status]}`}>{statusLabel[status]}</span>
)

export function Checkbox({ checked, onChange, label }: { checked: boolean; onChange: () => void; label: string }) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={checked}
      aria-label={label}
      onClick={onChange}
      className="relative block size-12 shrink-0 rounded-lg outline-offset-[-4px] focus-visible:outline-2 focus-visible:outline-brand"
    >
      <span
        className={`absolute left-3 top-3 size-6 rounded-md border-2 border-solid transition-colors ${
          checked ? 'border-brand bg-brand' : 'border-[#94a3b8] bg-white'
        }`}
      />
      {checked && <Icon name="c3151" size={20} className="absolute left-[14px] top-[14px]" />}
    </button>
  )
}

export function TodoCard({ todo, onToggle }: { todo: Todo; onToggle: () => void }) {
  return (
    <div className="animate-fade-up flex shrink-0 rounded-xl border border-line bg-white pb-[17px] pl-[3px] pr-[21px] pt-[15px]">
      <Checkbox checked={todo.done} onChange={onToggle} label={todo.done ? 'Tandai belum selesai' : 'Tandai selesai'} />
      <div className="ml-2 min-w-0 flex-1">
        <p className={`min-h-12 text-base leading-6 text-ink ${todo.done ? 'line-through opacity-[0.64]' : ''}`}>{todo.title}</p>
        <div className="mt-2 flex flex-wrap gap-2">
          <CategoryChip cat={todo.cat} />
          {todo.due && <DueChip label={todo.due} />}
        </div>
        <p className="mt-2 text-[13px] font-medium leading-[18px] text-muted">{todo.source}</p>
      </div>
    </div>
  )
}

export function ResultCard({
  rec,
  todos,
  onToggle,
  onSummary,
}: {
  rec: Rec
  todos: Todo[]
  onToggle: (id: string) => void
  onSummary: (text: string) => void
}) {
  const [editing, setEditing] = useState(false)
  const [copied, setCopied] = useState(false)

  const copy = async () => {
    const text = [
      rec.summary,
      '',
      'Poin penting',
      ...rec.points.map((p) => `• ${p}`),
      '',
      'To-do dari rekaman',
      ...todos.map((t) => `- ${t.title}`),
    ].join('\n')
    try {
      await navigator.clipboard.writeText(text)
    } catch {
      /* clipboard may be blocked in iframes; still show feedback */
    }
    setCopied(true)
    setTimeout(() => setCopied(false), 1600)
  }

  return (
    <section className="animate-fade-up flex flex-col items-start gap-2 rounded-xl border border-line bg-white p-4">
      <CategoryChip cat={rec.cat} />
      {editing ? (
        <textarea
          autoFocus
          value={rec.summary}
          onChange={(e) => onSummary(e.target.value)}
          rows={5}
          aria-label="Ubah rangkuman"
          className="w-full resize-none rounded-lg border border-brand bg-white p-2 text-base leading-6 text-ink outline-none"
        />
      ) : (
        <p className="text-base leading-6 text-ink">{rec.summary}</p>
      )}
      <h3 className="text-base font-semibold leading-6 text-ink">Poin penting</h3>
      <ul className="text-base leading-6 text-ink">
        {rec.points.map((p) => (
          <li key={p}>• {p}</li>
        ))}
      </ul>
      <h3 className="text-base font-semibold leading-6 text-ink">To-do dari rekaman</h3>
      <div className="w-full">
        {todos.map((t) => (
          <div key={t.id} className="flex min-h-12 w-full items-start">
            <Checkbox checked={t.done} onChange={() => onToggle(t.id)} label={t.title} />
            <p className={`ml-1 flex-1 text-base leading-6 text-ink ${t.done ? 'line-through opacity-[0.64]' : ''}`}>{t.title}</p>
          </div>
        ))}
      </div>
      <div className="grid w-full grid-cols-2 gap-4">
        <button
          type="button"
          onClick={copy}
          className="flex h-12 items-center justify-center gap-2 rounded-lg border border-line bg-white text-[13px] font-medium text-brand active:bg-slate-50"
        >
          <Icon name="fe80c" size={20} />
          {copied ? 'Tersalin' : 'Salin'}
        </button>
        <button
          type="button"
          onClick={() => setEditing((v) => !v)}
          className="flex h-12 items-center justify-center gap-2 rounded-lg border border-line bg-white text-[13px] font-medium text-brand active:bg-slate-50"
        >
          <Icon name="205a8" size={20} />
          {editing ? 'Simpan' : 'Edit'}
        </button>
      </div>
    </section>
  )
}

export function ProcessingCard({ duration }: { duration: string }) {
  return (
    <div className="animate-fade-up flex flex-col gap-4 rounded-xl border border-line bg-white p-4" role="status">
      <div className="flex min-h-12 items-start gap-3">
        <Icon name="64149" className="mt-0.5 animate-spin" />
        <p className="text-base font-medium leading-6 text-ink">Merangkum rekaman {duration}...</p>
      </div>
      {['w-[96%]', 'w-[88%]', 'w-[70%]'].map((w) => (
        <div key={w} className={`h-3 animate-pulse rounded-md bg-[#f1f5f9] ${w}`} />
      ))}
    </div>
  )
}

export function FailedCard({ onRetry }: { onRetry: () => void }) {
  return (
    <div className="animate-fade-up flex flex-col gap-4 rounded-xl border border-line bg-white p-4" role="alert">
      <div className="flex items-start gap-3">
        <Icon name="ef444" className="mt-0.5" />
        <p className="text-base font-medium leading-6 text-ink">Gagal memproses. Rekamanmu aman tersimpan.</p>
      </div>
      <button
        type="button"
        onClick={onRetry}
        className="h-12 w-full rounded-lg bg-brand text-base font-semibold text-white transition-colors hover:bg-[#4338ca] active:bg-[#3730a3]"
      >
        Coba lagi
      </button>
    </div>
  )
}

export function BottomNav({ active, onNavigate }: { active: 'home' | 'history'; onNavigate: (t: 'home' | 'history') => void }) {
  const item = (tab: 'home' | 'history', label: string, on: string, off: string) => {
    const isActive = active === tab
    return (
      <button
        type="button"
        onClick={() => onNavigate(tab)}
        aria-current={isActive ? 'page' : undefined}
        className={`flex flex-1 flex-col items-center gap-1.5 pt-1 text-[13px] font-medium leading-[18px] ${isActive ? 'text-brand' : 'text-muted'}`}
      >
        <Icon name={isActive ? on : off} />
        {label}
      </button>
    )
  }
  return (
    <nav className="flex h-[76px] shrink-0 border-t border-line bg-white px-[15px] pt-[5px]">
      {item('home', 'Beranda', '4e7e2', '092e5')}
      {item('history', 'Riwayat', 'a5952', '6a971')}
    </nav>
  )
}

export function RecordArea({ onRecord }: { onRecord: () => void }) {
  return (
    <div className="flex h-[120px] shrink-0 flex-col items-center bg-surface pt-2">
      <button
        type="button"
        onClick={onRecord}
        aria-label="Mulai merekam"
        className="grid size-[72px] place-items-center rounded-full bg-rec shadow-[0_4px_6px_rgba(229,72,77,0.18)] transition-transform active:scale-95"
      >
        <Icon name="f6459" />
      </button>
      <p className="mt-2 text-[13px] font-medium leading-[18px] text-muted">Ketuk untuk merekam</p>
    </div>
  )
}
