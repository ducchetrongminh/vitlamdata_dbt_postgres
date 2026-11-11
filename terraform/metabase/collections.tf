# Collections managed here: the SQL course (5738) and everything under it,
# "# Learners" (5737) alone, and "SQL Query Thuc Chien" (315). Learners create
# their own collections under 5737; those are not managed, and Terraform never
# touches a collection it does not manage. Deleting one archives its questions
# and dashboards with it, hence prevent_destroy.
#
# `parent` is a Metabase collection id (null = root), not a Terraform
# reference: every collection here already exists. A new collection under a
# managed one can still use the parent's id.
locals {
  watch_video = "Xem video trước khi làm yêu cầu: "

  collections = {
    learners       = { id = 5737, parent = null, name = "# Learners", description = null }
    sql_thuc_chien = { id = 315, parent = null, name = "SQL Query Thuc Chien", description = null }
    sql_course     = { id = 5738, parent = null, name = "Khóa học SQL Query mở rộng", description = null }

    # Seasons (Mùa) and topics (Chuyên đề) of the SQL course.
    sql_a = { id = 5739, parent = 5738, name = "A Mùa 01: SELECT FROM WHERE", description = "${local.watch_video}https://youtu.be/FUotBX7zNs8" }
    sql_b = { id = 5750, parent = 5738, name = "B Mùa 02: GROUP BY", description = "${local.watch_video}https://youtu.be/9mYjH5Gw3_k" }
    sql_c = { id = 6498, parent = 5738, name = "C Mùa 03: CASE WHEN", description = "${local.watch_video}https://youtu.be/inHTadgmMdY" }
    sql_d = { id = 6512, parent = 5738, name = "D Mùa 04: WITH (CTE)", description = "${local.watch_video}https://youtu.be/yXtOdRDl8GQ" }
    sql_e = { id = 6513, parent = 5738, name = "E Mùa 05: TIMESTAMP", description = "${local.watch_video}https://youtu.be/RPDU13sXGEU" }
    sql_f = { id = 6514, parent = 5738, name = "F Mùa 06: LEFT JOIN", description = "Xem trước chuỗi Data modeling: https://www.youtube.com/playlist?list=PL01fPqVNMdrlMwymamk6zuISnC6USwAtI\n\n${local.watch_video}https://youtu.be/k7UI0E-n198" }
    sql_g = { id = 6515, parent = 5738, name = "G Mùa 07: Tổng hợp", description = "${local.watch_video}https://youtu.be/YeEwrECWvCQ" }
    sql_h = { id = 6516, parent = 5738, name = "H Mùa 08: Sumif, countif", description = null }
    sql_i = { id = 6519, parent = 5738, name = "I Mùa 09: Subquery", description = null }
    sql_j = { id = 6652, parent = 5738, name = "J Chuyên đề 01: Data profiling", description = null }
    sql_k = { id = 6517, parent = 5738, name = "K Mùa 10: Loại dữ liệu", description = null }
    sql_l = { id = 6518, parent = 5738, name = "L Chuyên đề 02: Data cleaning", description = "${local.watch_video}https://youtu.be/LllrDN7p1bU" }
    sql_m = { id = 6520, parent = 5738, name = "M Chuyên đề 03: Data shaping", description = null }
    sql_n = { id = 6703, parent = 5738, name = "N Chuyên đề 04: Summary table", description = null }
    sql_o = { id = 6521, parent = 5738, name = "O Mùa 11: Window Functions", description = "${local.watch_video}https://youtu.be/nc1BQUb64ek" }
    sql_p = { id = 6737, parent = 5738, name = "P Chuyên đề 05: Periodic snapshot table", description = null }
    sql_q = { id = 7523, parent = 5738, name = "Q Chuyên đề 06: Tổng hợp", description = null }

    # One "Bài kiểm tra" (test) collection inside some seasons.
    sql_a_test = { id = 6766, parent = 5739, name = "Bài kiểm tra", description = null }
    sql_b_test = { id = 6772, parent = 5750, name = "Bài kiểm tra", description = null }
    sql_c_test = { id = 6852, parent = 6498, name = "Bài kiểm tra", description = null }
    sql_d_test = { id = 6853, parent = 6512, name = "Bài kiểm tra", description = null }
    sql_e_test = { id = 6854, parent = 6513, name = "Bài kiểm tra", description = null }
    sql_f_test = { id = 6855, parent = 6514, name = "Bài kiểm tra", description = null }
    sql_g_test = { id = 6856, parent = 6515, name = "Bài kiểm tra", description = null }
    sql_h_test = { id = 7031, parent = 6516, name = "Bài kiểm tra", description = null }
    sql_i_test = { id = 7032, parent = 6519, name = "Bài kiểm tra", description = null }
    sql_k_test = { id = 7033, parent = 6517, name = "Bài kiểm tra", description = null }
    sql_o_test = { id = 7262, parent = 6521, name = "Bài kiểm tra", description = null }
  }
}

# shortcut: one-time adoption of the existing collections. Delete these blocks
# after the apply that imports them.
import {
  for_each = local.collections

  to = metabase_collection.this[each.key]
  id = tostring(each.value.id)
}

resource "metabase_collection" "this" {
  for_each = local.collections

  name        = each.value.name
  description = each.value.description
  parent_id   = each.value.parent

  lifecycle {
    prevent_destroy = true
  }
}
