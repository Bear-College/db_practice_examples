"""
CRUD — Create, Read, Update, Delete with Session.

Run: python example.py
"""
from __future__ import annotations

from sqlalchemy import ForeignKey, String, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, Session


class Base(DeclarativeBase):
    pass


class Item(Base):
    __tablename__ = "items"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(100))
    qty: Mapped[int] = mapped_column(default=0)


def main() -> None:
    engine = create_engine("sqlite:///05_crud_lab.db", echo=False)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    # CREATE
    with Session(engine) as session:
        session.add_all([Item(name="Bolt M8", qty=100), Item(name="Washer", qty=250)])
        session.commit()

    # READ
    with Session(engine) as session:
        one = session.scalars(select(Item).where(Item.name == "Bolt M8")).one()
        all_rows = session.scalars(select(Item).order_by(Item.id)).all()
        print("READ one / all:", one.id, [r.name for r in all_rows])

    # UPDATE
    with Session(engine) as session:
        row = session.scalars(select(Item).where(Item.id == 1)).one()
        row.qty -= 3
        session.commit()

    with Session(engine) as session:
        print("After UPDATE:", session.get(Item, 1).qty)

    # DELETE
    with Session(engine) as session:
        row = session.scalars(select(Item).where(Item.id == 2)).one()
        session.delete(row)
        session.commit()

    with Session(engine) as session:
        remaining = session.scalars(select(Item)).all()
        print("After DELETE:", [(r.id, r.name) for r in remaining])


if __name__ == "__main__":
    main()
