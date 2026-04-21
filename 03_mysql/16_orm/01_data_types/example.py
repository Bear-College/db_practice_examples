"""
Типи даних / Data types — SQLAlchemy column types mapped to Python.

Run: python example.py   (from this directory)
"""
from __future__ import annotations

import enum
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    Date,
    DateTime,
    Enum,
    Float,
    Integer,
    LargeBinary,
    Numeric,
    String,
    Text,
    create_engine,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, Session


class Base(DeclarativeBase):
    pass


class OrderStatus(str, enum.Enum):
    new = "new"
    paid = "paid"


class Product(Base):
    """Shows common SQLAlchemy ↔ Python type pairings."""

    __tablename__ = "products"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    sku: Mapped[str] = mapped_column(String(32), unique=True)
    name: Mapped[str] = mapped_column(Text)
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    units_in_stock: Mapped[int] = mapped_column(BigInteger, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    release_date: Mapped[datetime | None] = mapped_column(Date, nullable=True)
    attrs: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    photo: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)
    status: Mapped[OrderStatus] = mapped_column(Enum(OrderStatus), default=OrderStatus.new)


def main() -> None:
    engine = create_engine("sqlite:///01_data_types_lab.db", echo=False)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        p = Product(
            sku="OIL-1L",
            name="Engine oil 1L",
            price=Decimal("24.99"),
            weight_kg=0.95,
            attrs={"viscosity": "5W-30", "brand": "Demo"},
        )
        session.add(p)
        session.commit()
        session.refresh(p)
        print("Inserted:", p.id, p.sku, p.price, p.attrs, p.status)

    # Show emitted CREATE TABLE (SQLite)
    from sqlalchemy.schema import CreateTable

    print("\nSQLite DDL fragment:")
    print(CreateTable(Product.__table__).compile(dialect=engine.dialect))


if __name__ == "__main__":
    main()
