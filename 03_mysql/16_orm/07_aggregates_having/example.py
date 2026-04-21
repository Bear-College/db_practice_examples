"""
Агрегатні функції, групування та HAVING — func.count, sum, group_by, having.

Run: python example.py
"""
from __future__ import annotations

from decimal import Decimal

from sqlalchemy import ForeignKey, Numeric, String, create_engine, func, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, Session


class Base(DeclarativeBase):
    pass


class Part(Base):
    __tablename__ = "parts"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    category: Mapped[str] = mapped_column(String(40))
    sku: Mapped[str] = mapped_column(String(40))
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2))


def main() -> None:
    engine = create_engine("sqlite:///07_aggregates_lab.db", echo=False)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        session.add_all(
            [
                Part(category="filters", sku="F-1", price=Decimal("12.00")),
                Part(category="filters", sku="F-2", price=Decimal("15.00")),
                Part(category="brakes", sku="B-1", price=Decimal("40.00")),
            ]
        )
        session.commit()

    with Session(engine) as session:
        stmt = (
            select(Part.category, func.count(Part.id).label("n"), func.avg(Part.price).label("avg_price"))
            .group_by(Part.category)
            .having(func.count(Part.id) >= 1)
            .order_by(Part.category)
        )
        print("GROUP BY + HAVING:", session.execute(stmt).all())

        total = session.scalar(select(func.sum(Part.price)))
        print("SUM(all prices):", total)


if __name__ == "__main__":
    main()
