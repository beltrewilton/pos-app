import {LANGUAGES, getLanguage, money, t} from "../i18n"

const str = value => value == null ? "" : String(value)

export class ReceiptFormatter {
  constructor(config = {}) {
    this.config = {columns: 48, ...config}
  }

  receipt(sale) {
    console.log("[printer] ReceiptFormatter.receipt", {sequence: sale?.sequence, copyLabel: ""})
    return this.document("", sale)
  }

  payment(sale, payment) {
    console.log("[printer] ReceiptFormatter.payment", {sequence: sale?.sequence, paymentId: payment?.id, copyLabel: ""})
    return this.document("", sale, payment)
  }

  invoice(sale) {
    console.log("[printer] ReceiptFormatter.invoice", {sequence: sale?.sequence, copyLabel: t("receipts.copy")})
    return this.document(t("receipts.copy"), sale)
  }

  document(copyLabel, sale, payment = null) {
    const columns = this.config.columns
    const store = sale.store || {}
    const client = sale.client || sale.customer || {}
    const payments = receiptPayments(sale, payment)
    const paid = sum(payments.map(item => item.amount))
    const paidToDate = number(sale.total_paid) > 0 ? number(sale.total_paid) : paid
    const pending = Math.max(0, number(sale.due_balance ?? number(sale.amount) - paid))
    const savings = number(sale.discount || 0) + sum((sale.lines || []).map(line => line.discount))
    const items = sum((sale.lines || []).map(line => line.quantity || line.qty || 0))
    const sequence = str(sale.sequence || sale.id || "-")

    const lines = [
      store.logo ? {type: "image", image: store.logo, align: "center", width: 286} : null,
      store.address ? {align: "center", text: wrap(str(store.address).toUpperCase(), columns)} : null,
      store.slogan ? {align: "center", text: wrap(str(store.slogan).toUpperCase(), columns)} : null,
      {text: rule(columns)},
      {text: twoCol(t("receipts.rnc"), str(store.company_id || store.rnc || store.company_rnc || ""), columns)},
      {text: twoCol(t("receipts.encf"), sequence, columns)},
      {text: twoCol(t("receipts.date"), receiptDate(sale.date_create), columns)},
      {text: twoCol(t("receipts.customer"), str(sale.client_name || client.name || t("receipts.consumerFinal")), columns)},
      {text: twoCol(t("receipts.document"), str(sale.client_document_id || client.document_id || ""), columns)},
      {text: twoCol(t("receipts.salesperson"), str(sale.login || ""), columns)},
      copyLabel ? {align: "center", text: copyLabel} : null,
      {align: "center", text: sale.status === "CREDIT" ? t("receipts.creditInvoice") : t("receipts.salesJournal")},
      {text: rule(columns)},
      {text: columnsHeader(columns)}
    ].filter(Boolean)

    for (const item of sale.lines || sale.items || []) {
      const product = item.product || {}
      const name = str(item.name || product.name || `${t("receipts.product")} ${item.product_id || ""}`).toUpperCase()
      const sku = str(product.code || item.code || item.sku || item.product_id || "")
      const qty = number(item.quantity || item.qty || 1)
      const unit = number(item.amount || item.price || product.price || 0)
      const total = number(item.total_amount || item.total || unit * qty)
      const tax = itemTax(item, total)
      const valueBeforeTax = Math.max(0, total - tax)
      const unitBeforeTax = qty > 0 ? valueBeforeTax / qty : valueBeforeTax
      lines.push({text: wrap(name, columns)})
      if (sku) lines.push({text: `SKU: ${sku}`.slice(0, columns)})
      lines.push({text: itemLine(qty, unitBeforeTax, tax, valueBeforeTax, columns)})
    }

    lines.push({text: rule(columns)})
    lines.push({text: amountLine(t("common.subtotal"), sale.sub || sale.subtotal, columns)})
    lines.push({text: amountLine(t("receipts.itbis"), sale.tax_amount || sale.tax, columns)})
    if (number(sale.discount) > 0) lines.push({text: amountLine(t("receipts.discount"), -number(sale.discount), columns)})
    if (number(sale.delivery_charge || sale.delivery) > 0) lines.push({text: amountLine(t("receipts.delivery"), sale.delivery_charge || sale.delivery, columns)})
    lines.push({bold: true, text: amountLine(t("common.total"), sale.amount || sale.total, columns)})
    if (savings > 0) lines.push({text: amountLine(t("receipts.purchaseSavings"), savings, columns)})
    lines.push({text: twoCol(t("receipts.articles"), String(items), columns)})
    lines.push({text: rule(columns)})

    for (const item of payments) lines.push({text: paymentLine(item, columns)})
    if (paidToDate > 0) lines.push({text: amountLine(t("receipts.paidToDate"), paidToDate, columns)})
    if (pending > 0) lines.push({text: amountLine(t("receipts.pendingBalance"), pending, columns)})
    if (number(sale.change_amount) > 0) lines.push({text: amountLine(t("receipts.change"), sale.change_amount, columns)})

    lines.push({text: rule(columns)})
    lines.push({align: "center", text: t("receipts.thanks")})
    lines.push({align: "center", text: `${t("receipts.receipt")}: ${sequence}`})
    return lines
  }
}

function columnsHeader(columns) {
  return twoCol(t("receipts.description"), `${t("receipts.itbis")}      ${t("receipts.value")}`, columns)
}

function itemLine(qty, unit, tax, total, columns) {
  const left = `${trimNumber(qty)} x ${money(unit)}`
  const taxValue = money(tax)
  const right = money(total)
  const taxColumn = taxValue.padStart(10)
  const rightColumn = right.padStart(12)
  return `${left}`.padEnd(Math.max(1, columns - taxColumn.length - rightColumn.length)).slice(0, columns - taxColumn.length - rightColumn.length) + taxColumn + rightColumn
}

function itemTax(item, total) {
  const quantity = number(item.quantity || item.qty || 1)
  const explicit = number(item.tax_amount || item.tax)
  if (explicit > 0) return explicit * quantity
  const unit = number(item.amount || item.price || item.product?.price || 0)
  const subtotal = number(item.sub || item.subtotal || 0) * quantity
  if (subtotal > 0) return Math.max(0, total - subtotal)
  return Math.max(0, total - total / 1.18)
}

function amountLine(label, value, columns) {
  return twoCol(label, money(value), columns)
}

function twoCol(left, right, columns) {
  left = str(left)
  right = str(right)
  const space = Math.max(1, columns - left.length - right.length)
  return `${left}${" ".repeat(space)}${right}`
}

function rule(columns) {
  return "-".repeat(columns)
}

function wrap(value, columns) {
  const words = str(value).split(/\s+/)
  const result = []
  let line = ""
  for (const word of words) {
    if (`${line} ${word}`.trim().length > columns) {
      if (line) result.push(line)
      line = word
    } else {
      line = `${line} ${word}`.trim()
    }
  }
  if (line) result.push(line)
  return result.join("\n")
}

function receiptDate(value) {
  const date = value ? new Date(value) : new Date()
  if (Number.isNaN(date.getTime())) return str(value)
  return date.toLocaleString(currentLocale(), {year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit"})
}

function paymentLabel(type) {
  return type === "CC" ? t("receipts.creditCard") : t("receipts.cash")
}

function paymentLine(payment, columns) {
  const date = shortDate(payment.date_create || payment.date)
  const amount = money(payment.amount)
  const amountWidth = 12
  const dateWidth = 12
  const methodWidth = Math.max(1, columns - dateWidth - amountWidth)
  return paymentLabel(payment.type).padEnd(methodWidth).slice(0, methodWidth) +
    str(date).padStart(dateWidth).slice(0, dateWidth) +
    amount.padStart(amountWidth).slice(0, amountWidth)
}

function receiptPayments(sale, payment) {
  const payments = [...(sale.payments || sale.sale_paids || [])]
  if (!payment) return payments
  const exists = payments.some(item => item.id != null && payment.id != null && String(item.id) === String(payment.id))
  return exists ? payments : [...payments, payment]
}

function shortDate(value) {
  const date = value ? new Date(value) : null
  if (!date || Number.isNaN(date.getTime())) return str(value)
  return date.toLocaleDateString(currentLocale(), {year: "numeric", month: "2-digit", day: "2-digit"})
}

function columnAmountLine(label, value, columns) {
  const amount = money(value)
  const amountColumn = amount.padStart(12)
  return str(label).padEnd(columns - amountColumn.length).slice(0, columns - amountColumn.length) + amountColumn
}

function number(value) {
  return Number(value || 0)
}

function sum(values) {
  return values.reduce((total, value) => total + number(value), 0)
}

function trimNumber(value) {
  return Number.isInteger(Number(value)) ? String(Number(value)) : Number(value).toFixed(2)
}

function currentLocale() {
  return LANGUAGES[getLanguage()]?.locale || LANGUAGES.en.locale
}
