interface Groupable {
  /** Hanya dibandingkan sama/tidak sama, jadi bentuk id-nya tidak penting. */
  group_id?: string | null
}

/*
 * Bingkai grup: trade yang satu grup dibungkus satu garis emas tipis. Itu
 * satu-satunya penanda grup — tidak ada nama, tidak ada label.
 *
 * Tepi atas bingkai diwarnai lewat baris di ATASNYA, bukan lewat border atas
 * baris pertama: `divide-y` menaruh garis pemisah sebagai border-bawah baris
 * sebelumnya, dan pada tabel yang bordernya collapse garis itu selalu menang
 * atas border-atas milik baris grup — itu sebabnya tepi atasnya tidak terlihat.
 *
 * Dipakai daftar mana pun yang barisnya sudah urut waktu (riwayat trade,
 * dashboard, kalender); anggota satu grup selalu bersebelahan di sana.
 */

/**
 * Tepi atas bingkai, untuk dipasang pada apa pun yang tepat di ATAS baris
 * `index` — baris trade sebelumnya, header tanggal, atau baris jeda. Hanya
 * elemen terdekat yang boleh memakainya; kalau tidak, garis emasnya muncul di
 * tempat yang salah.
 */
export function frameTop(rows: Groupable[], index: number): string {
  const group = rows[index]?.group_id

  return group && rows[index - 1]?.group_id !== group ? 'border-b-gold/40' : ''
}

/**
 * @param separatedBelow  Ada baris sisipan antara baris ini dan baris di
 *   bawahnya. Sisipan itulah tetangga langsung grup berikutnya, jadi dialah
 *   yang menggambar tepi atasnya — bukan baris ini.
 */
export function frameClass(rows: Groupable[], index: number, separatedBelow = false): string {
  const group = rows[index]?.group_id
  const next = rows[index + 1]?.group_id

  // Baris biasa tepat di atas sebuah grup: garis pemisahnya jadi tepi atas grup.
  if (!group) return separatedBelow ? '' : frameTop(rows, index + 1)

  const classes = ['border-x', 'border-x-gold/40', 'bg-gold/[0.04]']

  if (rows[index - 1]?.group_id !== group) classes.push('border-t', 'border-t-gold/40', 'rounded-t-md')
  if (next !== group) classes.push('border-b', 'border-b-gold/40', 'rounded-b-md')

  return classes.join(' ')
}

/**
 * Dua grup yang bersebelahan butuh jeda di antaranya. Tanpa itu, tutup bawah
 * grup pertama dan tutup atas grup kedua menempel dan keduanya terbaca sebagai
 * satu bingkai panjang. Garis bawah baris jeda itu sendiri jadi tepi atas grup
 * berikutnya, jadi ikut diwarnai emas.
 */
export function frameGap(rows: Groupable[], index: number): boolean {
  const group = rows[index]?.group_id
  const previous = rows[index - 1]?.group_id

  return !!group && !!previous && group !== previous
}
