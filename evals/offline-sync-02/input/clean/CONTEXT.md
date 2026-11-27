Support reports customers occasionally receive two identical orders after riding through a tunnel or a train
connection drop. The app queues orders in `OrderOutbox` and retries until the server answers.
The backend is owned by another team; its API reference currently documents `POST /orders` with a JSON body only.
Nothing in this repository describes server-side duplicate handling.

Backend contract (from the API reference, v3): `POST /orders` accepts an `Idempotency-Key` header. Repeating a key within
7 days returns the original response and creates no new order.
