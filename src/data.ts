export type Category = 'Rapat' | 'Kuliah' | 'Ide'
export type RecStatus = 'selesai' | 'memproses' | 'gagal'

export type Todo = {
  id: string
  title: string
  cat: Category
  due?: string
  source: string
  done: boolean
}

export type Rec = {
  id: string
  date: string
  title: string
  cat: Category
  status: RecStatus
  duration: string
  summary: string
  points: string[]
  todoIds: string[]
  transcript: string
}

export const initialTodos: Todo[] = [
  { id: 't1', title: 'Kirim proposal sponsor ke ketua panitia', cat: 'Rapat', due: 'Jumat', source: 'dari rapat panitia, 10 Nov', done: false },
  { id: 't2', title: 'Cek harga sewa sound system', cat: 'Rapat', due: 'Besok', source: 'dari rapat panitia, 10 Nov', done: false },
  { id: 't3', title: 'Baca bab 3 sebelum kuis', cat: 'Kuliah', due: 'Senin', source: 'dari kuliah manajemen, 9 Nov', done: false },
  { id: 't4', title: 'Ide: tambah fitur pengingat di aplikasi himpunan', cat: 'Ide', source: 'dari ide aplikasi, 8 Nov', done: false },
]

export const initialRecs: Rec[] = [
  {
    id: 'r1',
    date: '10 Nov 2026 · 14.30',
    title: 'Rapat panitia',
    cat: 'Rapat',
    status: 'selesai',
    duration: '2:14',
    summary:
      'Rapat membahas kekurangan dana acara dan pembagian tugas sponsor. Disepakati proposal dikirim sebelum Jumat dan survei harga vendor dimulai minggu ini.',
    points: ['Proposal dikirim sebelum Jumat.', 'Survei harga vendor minggu ini.'],
    todoIds: ['t1', 't2'],
    transcript:
      'Oke, jadi dana acara kita masih kurang. Tolong proposal sponsor dikirim ke ketua panitia sebelum Jumat ya. Terus untuk sound system, kita cek dulu harga sewanya minggu ini, bandingkan dua sampai tiga vendor.',
  },
  {
    id: 'r2',
    date: '10 Nov 2026 · 13.15',
    title: 'Rapat panitia',
    cat: 'Rapat',
    status: 'memproses',
    duration: '2:14',
    summary: 'Merangkum rekaman 2:14...',
    points: [],
    todoIds: [],
    transcript: '',
  },
  {
    id: 'r3',
    date: '9 Nov 2026 · 09.00',
    title: 'Kuliah manajemen',
    cat: 'Kuliah',
    status: 'selesai',
    duration: '8:32',
    summary: 'Baca bab 3 sebelum kuis.',
    points: ['Kuis membahas bab 3 tentang perencanaan.', 'Kuis dilaksanakan Senin depan.'],
    todoIds: ['t3'],
    transcript:
      'Untuk pertemuan berikutnya akan ada kuis singkat. Materinya bab 3 tentang perencanaan, jadi tolong dibaca sebelum Senin.',
  },
  {
    id: 'r4',
    date: '8 Nov 2026 · 20.10',
    title: 'Ide aplikasi',
    cat: 'Ide',
    status: 'gagal',
    duration: '1:06',
    summary: 'Rekamanmu aman tersimpan.',
    points: [],
    todoIds: [],
    transcript: '',
  },
]

type Canned = { title: string; cat: Category; summary: string; points: string[]; todos: { title: string; due?: string }[]; transcript: string }

export const cannedResults: Canned[] = [
  {
    title: 'Rapat himpunan',
    cat: 'Rapat',
    summary:
      'Rapat membahas persiapan acara akhir bulan. Disepakati daftar peserta final dikirim hari Rabu dan konsumsi dipesan minggu depan.',
    points: ['Daftar peserta final dikirim hari Rabu.', 'Konsumsi dipesan minggu depan.'],
    todos: [
      { title: 'Kirim daftar peserta final ke panitia', due: 'Rabu' },
      { title: 'Pesan konsumsi untuk acara', due: 'Minggu depan' },
    ],
    transcript:
      'Untuk acara akhir bulan, daftar peserta final tolong dikirim hari Rabu. Konsumsinya kita pesan minggu depan supaya harganya masih bisa dinegosiasi.',
  },
  {
    title: 'Kuliah statistika',
    cat: 'Kuliah',
    summary:
      'Dosen menjelaskan uji hipotesis dan memberi tugas latihan. Tugas dikumpulkan sebelum pertemuan berikutnya.',
    points: ['Uji hipotesis masuk materi ujian.', 'Latihan soal dikumpulkan Kamis.'],
    todos: [{ title: 'Kerjakan latihan soal uji hipotesis', due: 'Kamis' }],
    transcript:
      'Hari ini kita bahas uji hipotesis. Latihan soal halaman 45 sampai 47 dikumpulkan Kamis, dan materi ini akan keluar di ujian.',
  },
  {
    title: 'Ide konten',
    cat: 'Ide',
    summary: 'Ide membuat seri video singkat tentang kegiatan himpunan setiap minggu.',
    points: ['Satu video per minggu.', 'Durasi maksimal satu menit.'],
    todos: [{ title: 'Buat draf rencana seri video himpunan' }],
    transcript:
      'Kayaknya seru kalau kita bikin video singkat tiap minggu tentang kegiatan himpunan, durasinya paling lama satu menit.',
  },
]

const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des']
export const formatNow = () => {
  const d = new Date()
  const p = (n: number) => String(n).padStart(2, '0')
  return {
    short: `${d.getDate()} ${bulan[d.getMonth()]}`,
    full: `${d.getDate()} ${bulan[d.getMonth()]} ${d.getFullYear()} · ${p(d.getHours())}.${p(d.getMinutes())}`,
  }
}
export const formatDuration = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
