import { Icon, TodoCard, ProcessingCard, FailedCard, ResultCard, RecordArea } from './ui'
import type { Rec, Todo } from '../data'

export type Banner = { kind: 'processing' | 'failed' | 'result'; recId: string } | null

type Props = {
  todos: Todo[]
  recs: Rec[]
  banner: Banner
  filter: 'belum' | 'selesai'
  onFilter: (f: 'belum' | 'selesai') => void
  onToggle: (id: string) => void
  onRecord: () => void
  onRetry: (recId: string) => void
  onSummary: (recId: string, text: string) => void
}

export function HomeScreen({ todos, recs, banner, filter, onFilter, onToggle, onRecord, onRetry, onSummary }: Props) {
  const visible = todos.filter((t) => (filter === 'selesai' ? t.done : !t.done))
  const bannerRec = banner ? recs.find((r) => r.id === banner.recId) : undefined
  const showBanner = banner && bannerRec && filter === 'belum'

  return (
    <div className="flex h-full flex-col">
      <header className="shrink-0 px-4 pt-6">
        <h1 className="text-2xl font-semibold leading-8 text-ink">Voice-to-Todo</h1>
        <h2 className="mt-10 text-lg font-semibold leading-7 text-ink">To-do kamu</h2>
        <div role="tablist" className="mt-3 grid h-12 grid-cols-2 rounded-[10px] bg-[#eef2f6] p-1">
          {(['belum', 'selesai'] as const).map((f) => (
            <button
              key={f}
              role="tab"
              aria-selected={filter === f}
              onClick={() => onFilter(f)}
              className={`rounded-lg text-[13px] font-medium leading-[18px] transition-colors ${
                filter === f ? 'bg-white text-brand' : 'text-muted'
              }`}
            >
              {f === 'belum' ? 'Belum' : 'Selesai'}
            </button>
          ))}
        </div>
      </header>

      <div className="mt-2 flex-1 overflow-y-auto px-4 pb-3">
        <div className="flex flex-col gap-3">
          {showBanner && banner.kind === 'processing' && <ProcessingCard duration={bannerRec.duration} />}
          {showBanner && banner.kind === 'failed' && <FailedCard onRetry={() => onRetry(bannerRec.id)} />}
          {showBanner && banner.kind === 'result' && (
            <ResultCard
              rec={bannerRec}
              todos={todos.filter((t) => bannerRec.todoIds.includes(t.id))}
              onToggle={onToggle}
              onSummary={(text) => onSummary(bannerRec.id, text)}
            />
          )}
          {visible.map((t) => (
            <TodoCard key={t.id} todo={t} onToggle={() => onToggle(t.id)} />
          ))}
        </div>

        {visible.length === 0 && !showBanner && (
          <div className="animate-fade-up flex flex-col items-center gap-3 pt-[72px] text-center">
            <div className="grid size-[104px] place-items-center rounded-full bg-[#eef2ff]">
              <Icon name="e16fb" size={64} />
            </div>
            <p className="text-lg font-semibold leading-7 text-ink">
              {filter === 'belum' ? 'Belum ada to-do' : 'Belum ada to-do selesai'}
            </p>
            <p className="max-w-[310px] text-base leading-6 text-muted">
              {filter === 'belum'
                ? 'Rekam sesuatu, nanti kurangkum jadi daftar tugas.'
                : 'Centang to-do yang sudah beres, nanti muncul di sini.'}
            </p>
          </div>
        )}
      </div>

      <RecordArea onRecord={onRecord} />
    </div>
  )
}
