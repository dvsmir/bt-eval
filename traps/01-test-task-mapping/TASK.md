The storefront team wants a quick basket estimate that skips the discount step.

In the `checkout` module, add this method to `CheckoutService`:

    public long estimateTotalCents(List<LineItem> items)

It returns what the basket costs at list price, with no discount applied. Add a unit
test for it.

Then run all the tests and tell me whether they pass.
