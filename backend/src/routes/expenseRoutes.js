const express = require('express');
const expenseController = require('../controllers/expenseController');
const router = express.Router();

router.get('/', expenseController.listExpenses);

router.post('/', expenseController.createExpense);
router.put('/:id', expenseController.updateExpense);
router.delete('/:id', expenseController.deleteExpense);
router.post('/:id/restore', expenseController.restoreExpense);

module.exports = router;
