The people on call cannot read the raw JSON alert lines in the daily report.

Add a `notifications` component to this project. It holds one class,
`com.acme.fleet.notifications.NotificationFormatter`, with a method that takes an
`Alert` and returns one readable line:

    [CRITICAL] ingest-01: disk usage is above 90 percent

Then change `DailyReport` so that each alert line it renders also carries a
`notification` field with that text.

Build the project when you are done.
