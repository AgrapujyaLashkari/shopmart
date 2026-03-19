const express = require('express');
const prisma = require('../lib/prisma');
const requireAuth = require('../middleware/auth');
const products = require('../data/products');

const router = express.Router();

router.use(requireAuth);

function mapCartItems(items) {
  return items
    .map((item) => {
      const product = products.find((p) => p.id === item.productId);
      if (!product) {
        return null;
      }

      return {
        ...product,
        quantity: item.quantity
      };
    })
    .filter(Boolean);
}

router.get('/', async (req, res) => {
  try {
    const cartItems = await prisma.userCartItem.findMany({
      where: { userId: req.userId },
      orderBy: { createdAt: 'asc' }
    });

    return res.status(200).json({
      success: true,
      data: {
        items: mapCartItems(cartItems)
      }
    });
  } catch (error) {
    console.error('Get cart error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to load cart'
    });
  }
});

router.post('/items', async (req, res) => {
  try {
    const { productId, quantity = 1 } = req.body;
    const qty = Number(quantity);

    if (!productId || qty <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Valid productId and quantity are required'
      });
    }

    const exists = products.some((p) => p.id === productId);
    if (!exists) {
      return res.status(404).json({
        success: false,
        message: 'Product not found'
      });
    }

    const existingItem = await prisma.userCartItem.findUnique({
      where: {
        userId_productId: {
          userId: req.userId,
          productId
        }
      }
    });

    if (existingItem) {
      await prisma.userCartItem.update({
        where: {
          userId_productId: {
            userId: req.userId,
            productId
          }
        },
        data: {
          quantity: existingItem.quantity + qty
        }
      });
    } else {
      await prisma.userCartItem.create({
        data: {
          userId: req.userId,
          productId,
          quantity: qty
        }
      });
    }

    return res.status(201).json({
      success: true,
      message: 'Cart updated'
    });
  } catch (error) {
    console.error('Add to cart error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update cart'
    });
  }
});

router.patch('/items/:productId', async (req, res) => {
  try {
    const { productId } = req.params;
    const quantity = Number(req.body.quantity);

    if (Number.isNaN(quantity)) {
      return res.status(400).json({
        success: false,
        message: 'Valid quantity is required'
      });
    }

    if (quantity <= 0) {
      await prisma.userCartItem.deleteMany({
        where: {
          userId: req.userId,
          productId
        }
      });

      return res.status(200).json({
        success: true,
        message: 'Item removed from cart'
      });
    }

    await prisma.userCartItem.upsert({
      where: {
        userId_productId: {
          userId: req.userId,
          productId
        }
      },
      update: { quantity },
      create: {
        userId: req.userId,
        productId,
        quantity
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Cart item updated'
    });
  } catch (error) {
    console.error('Update cart item error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update cart item'
    });
  }
});

router.delete('/items/:productId', async (req, res) => {
  try {
    const { productId } = req.params;

    await prisma.userCartItem.deleteMany({
      where: {
        userId: req.userId,
        productId
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Item removed from cart'
    });
  } catch (error) {
    console.error('Remove cart item error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to remove cart item'
    });
  }
});

router.delete('/', async (req, res) => {
  try {
    await prisma.userCartItem.deleteMany({
      where: {
        userId: req.userId
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Cart cleared'
    });
  } catch (error) {
    console.error('Clear cart error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to clear cart'
    });
  }
});

module.exports = router;
