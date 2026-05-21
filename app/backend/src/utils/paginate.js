'use strict';

function paginate({ page, pageSize }, defaults = { page: 1, pageSize: 20, max: 100 }) {
  const p = Math.max(1, Number.parseInt(page, 10) || defaults.page);
  const sz = Math.min(
    defaults.max,
    Math.max(1, Number.parseInt(pageSize, 10) || defaults.pageSize)
  );
  return { page: p, pageSize: sz, offset: (p - 1) * sz, limit: sz };
}

module.exports = { paginate };
