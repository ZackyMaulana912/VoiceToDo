import { useCallback, useEffect, useRef, useState } from 'react'
import { BottomNav } from './components/ui'
import { RecordingScreen } from './components/RecordingScreen'
import { HomeScreen, type Banner } from './components/HomeScreen'
import { DetailScreen, HistoryScreen } from './components/HistoryScreens'
import { cannedResults, formatDuration, formatNow, initialRecs, initialTodos, type Rec, type Todo } from './data'

type Screen = { name: 'home' } | { name: 'recording' } | { name: 'history' } | { name: 'detail'; recId: string }

const PROCESS_MS = 2600
const MIN_SECONDS = 3 // recordings shorter than this fail to summarize

export default function App() {
  const [screen, setScreen] = useState<Screen>({ name: 'home' })
  const [todos, setTodos] = useState<Todo[]>(initialTodos)
  const [recs, setRecs] = useState<Rec[]>(initialRecs)
  const [filter, setFilter] = useState<'belum' | 'selesai'>('belum')
  const [banner, setBanner] = useState<Banner>(null)
  const counter = useRef(0)
  const timers = useRef<number[]>([])

  useEffect(() => () => timers.current.forEach(clearTimeout), [])

  const toggle = (id: string) => setTodos((ts) => ts.map((t) => (t.id === id ? { ...t, done: !t.done } : t)))
  const setSummary = (recId: string, summary: string) => setRecs((rs) => rs.map((r) => (r.id === recId ? { ...r, summary } : r)))

  // Summarize a recording: succeeds after a delay and creates its to-dos
  const summarize = useCallback((recId: string, fail: boolean) => {
    setRecs((rs) => rs.map((r) => (r.id === recId ? { ...r, status: 'memproses' } : r)))
    setBanner({ kind: 'processing', recId })
    const timer = window.setTimeout(() => {
      if (fail) {
        setRecs((rs) => rs.map((r) => (r.id === recId ? { ...r, status: 'gagal', summary: 'Rekamanmu aman tersimpan.' } : r)))
        setBanner({ kind: 'failed', recId })
        return
      }
      const canned = cannedResults[counter.current++ % cannedResults.length]
      const { short } = formatNow()
      const newTodos: Todo[] = canned.todos.map((t, i) => ({
        id: `${recId}-t${i}`,
        title: t.title,
        cat: canned.cat,
        due: t.due,
        source: `dari ${canned.title.toLowerCase()}, ${short}`,
        done: false,
      }))
      setTodos((ts) => [...newTodos, ...ts])
      setRecs((rs) =>
        rs.map((r) =>
          r.id === recId
            ? {
                ...r,
                status: 'selesai',
                title: canned.title,
                cat: canned.cat,
                summary: canned.summary,
                points: canned.points,
                transcript: canned.transcript,
                todoIds: newTodos.map((t) => t.id),
              }
            : r,
        ),
      )
      setBanner({ kind: 'result', recId })
    }, PROCESS_MS)
    timers.current.push(timer)
  }, [])

  const finishRecording = useCallback(
    (seconds: number) => {
      const id = `r-${Date.now()}`
      const rec: Rec = {
        id,
        date: formatNow().full,
        title: 'Rekaman baru',
        cat: 'Rapat',
        status: 'memproses',
        duration: formatDuration(seconds),
        summary: '',
        points: [],
        todoIds: [],
        transcript: '',
      }
      setRecs((rs) => [rec, ...rs])
      setFilter('belum')
      setScreen({ name: 'home' })
      summarize(id, seconds < MIN_SECONDS)
    },
    [summarize],
  )

  const go = (tab: 'home' | 'history') => {
    setScreen(tab === 'home' ? { name: 'home' } : { name: 'history' })
    if (tab === 'history') setBanner((b) => (b?.kind === 'processing' ? b : null))
  }

  const detailRec = screen.name === 'detail' ? recs.find((r) => r.id === screen.recId) : undefined
  const navActive = screen.name === 'history' || screen.name === 'detail' ? 'history' : 'home'

  return (
    <div className="mx-auto flex h-dvh w-full max-w-[480px] flex-col bg-surface sm:border-x sm:border-line">
      <div className="min-h-0 flex-1">
        {screen.name === 'recording' && <RecordingScreen onCancel={() => setScreen({ name: 'home' })} onFinish={finishRecording} />}
        {screen.name === 'home' && (
          <HomeScreen
            todos={todos}
            recs={recs}
            banner={banner}
            filter={filter}
            onFilter={(f) => {
              setFilter(f)
              if (banner && banner.kind !== 'processing') setBanner(null)
            }}
            onToggle={toggle}
            onRecord={() => setScreen({ name: 'recording' })}
            onRetry={(id) => summarize(id, false)}
            onSummary={setSummary}
          />
        )}
        {screen.name === 'history' && <HistoryScreen recs={recs} onOpen={(recId) => setScreen({ name: 'detail', recId })} />}
        {screen.name === 'detail' && detailRec && (
          <DetailScreen
            rec={detailRec}
            todos={todos.filter((t) => detailRec.todoIds.includes(t.id))}
            onBack={() => setScreen({ name: 'history' })}
            onToggle={toggle}
            onSummary={(text) => setSummary(detailRec.id, text)}
            onRetry={() => {
              summarize(detailRec.id, false)
              setFilter('belum')
              setScreen({ name: 'home' })
            }}
          />
        )}
      </div>
      {screen.name !== 'recording' && <BottomNav active={navActive} onNavigate={go} />}
    </div>
  )
}
